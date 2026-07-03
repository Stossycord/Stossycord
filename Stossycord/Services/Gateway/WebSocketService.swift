//
//  WebSocketService.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation
import AVFoundation
import KeychainSwift
import Network
import UIKit
import UserNotifications


class WebSocketService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isNetworkAvailable: Bool = true
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    @Published var userService = CurrentUserService.shared
    var deviceInfo: DeviceInfo = CurrentDeviceInfo.shared.deviceInfo
    
    // Custom threads
    private let webSocketQueue = DispatchQueue(label: "websocket.queue", qos: .utility)
    private let webSocketQueueKey = DispatchSpecificKey<Void>()
    private let heartbeatQueue = DispatchQueue(label: "heartbeat.queue", qos: .utility)
    private let memberChunkQueue = DispatchQueue(label: "gateway.member-chunks", qos: .utility)
    private var pendingMemberChunks: [String: Set<GuildMember>] = [:]
    private var pendingPresenceUpdates: [String: Presence] = [:]
    private var pendingMemberFlush: DispatchWorkItem?
    
    // Heartbeat properties
    private var heartbeatTimer: DispatchSourceTimer?
    private var lastHeartbeatAck: Bool = true
    private var heartbeatInterval: TimeInterval = 0
    private var isHeartbeatActive: Bool = false
    
    private let monitor = NWPathMonitor()
    private let networkQueue = DispatchQueue.global(qos: .background)
    
    // Reconnection properties
    private var reconnectionAttempts: Int = 0
    private var reconnectionTimer: DispatchSourceTimer?
    private var connectionWatchdogTimer: DispatchSourceTimer?
    private var isGatewayConnected: Bool = false
    private var isConnecting: Bool = false
    private var shouldReconnectAutomatically: Bool = true
    private var isMessageResyncInFlight: Bool = false
    
    // Add sequence number tracking for proper Discord protocol
    private var sequenceNumber: Int?
    
    // Session resumption properties
    private var sessionId: String?
    private var resumeGatewayUrl: String?
    private var shouldResume: Bool = false
    
    private static var clientHeartbeatSessionIDLastGenerated: Date = .distantPast
    
    private static var clientHeartbeatSessionCached: UUID? = nil
    
    static var clientHeartbeatSessionId: UUID {
        let now = Date()
        let refreshInterval: TimeInterval = 30 * 60
        
        if now.timeIntervalSince(clientHeartbeatSessionIDLastGenerated) > refreshInterval {
            clientHeartbeatSessionIDLastGenerated = now
            clientHeartbeatSessionCached = UUID()
        }
        
        return clientHeartbeatSessionCached!
    }
    
    
    private var zlibDecompressor: zlibService = zlibService()
    private var zlibBuffer = Data()
    private let ZLIB_SUFFIX: [UInt8] = [0x00, 0x00, 0xFF, 0xFF]
    
    // Thread safety
    private let stateQueue = DispatchQueue(label: "websocket.state", qos: .utility)
    
    static var shared = WebSocketService()
    
    private struct LoadedChannelSyncTarget {
        let channelId: String
        let guildId: String
        let afterMessageId: String
    }
    
    private init() {
        // currentUser = User(id: "", username: "", discriminator: "", avatar: "")
        webSocketQueue.setSpecific(key: webSocketQueueKey, value: ())
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        urlSession = URLSession(configuration: config)
        
        setupNetworkMonitor()
        
        
        if !userService.token.isEmpty {
            webSocketQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connect()
            }
        }
    }
    
    func connect() {
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Thread-safe state check
            var shouldConnect = false
            self.stateQueue.sync {
                shouldConnect = !self.isGatewayConnected && !self.isConnecting
            }
            
            guard shouldConnect else {
                print("Already connected or connecting, skipping connect()")
                return
            }
            
            let token = userService.token
            guard !token.isEmpty else {
                print("Token is empty!")
                return
            }
            
            print("Starting new WebSocket connection on custom thread...")
            
            // Set connecting state first, then clean up
            self.stateQueue.sync {
                self.isConnecting = true
                self.shouldReconnectAutomatically = true
            }
            
            // Clean up any existing connection (but don't reset isConnecting)
            self.cleanupConnection()
            
            // Reset connection state (but preserve session info for resume)
            if !self.shouldResume {
                self.stateQueue.sync {
                    self.sequenceNumber = nil
                    self.lastHeartbeatAck = true
                    self.isHeartbeatActive = false
                }
            } else {
                self.stateQueue.sync {
                    self.lastHeartbeatAck = true
                    self.isHeartbeatActive = false
                }
                print("Attempting to resume session with ID: \(self.sessionId ?? "unknown")")
            }
            
            // Use resume URL if available, otherwise use standard gateway
            let gatewayUrl: String
            if self.shouldResume, let resumeUrl = self.resumeGatewayUrl {
                gatewayUrl = resumeUrl
            } else {
                gatewayUrl = "wss://gateway.discord.gg/?encoding=json&v=9&compress=zlib-stream"
            }
            
            guard let url = URL(string: gatewayUrl) else {
                print("Invalid WebSocket URL: \(gatewayUrl)")
                self.stateQueue.sync {
                    self.isConnecting = false
                }
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue("https://discord.com", forHTTPHeaderField: "Origin")
            request.setValue(self.deviceInfo.browser_user_agent, forHTTPHeaderField: "User-Agent")
            request.setValue("websocket", forHTTPHeaderField: "Upgrade")
            request.setValue("Upgrade", forHTTPHeaderField: "Connection")
            request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
            request.setValue("discord-client", forHTTPHeaderField: "Sec-WebSocket-Protocol")
            request.timeoutInterval = 60
            
            self.webSocketTask = self.urlSession.webSocketTask(with: request)
            self.webSocketTask?.maximumMessageSize = 9999999
            self.webSocketTask?.resume()
            self.startConnectionWatchdog()
            
            print("WebSocket connection initiated on custom thread")
            
            self.stateQueue.sync {
                self.reconnectionAttempts = 0
            }
            
            self.receiveMessage()
        }
    }
    
    func disconnect() {
        print("Disconnecting WebSocket")
        
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.stateQueue.sync {
                self.shouldReconnectAutomatically = false
                self.isGatewayConnected = false
                self.isConnecting = false
                self.isHeartbeatActive = false
                self.shouldResume = false
                self.sessionId = nil
                self.resumeGatewayUrl = nil
                self.sequenceNumber = nil
            }
            
            self.cleanupConnection()
            
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            
            self.zlibDecompressor = zlibService()
            self.zlibBuffer = Data()
            
            Task { @MainActor in
                self.isConnected = false
            }
        }
    }
    
    private func cleanupConnection() {
        // Cancel heartbeat timer on heartbeat queue
        heartbeatQueue.async { [weak self] in
            self?.heartbeatTimer?.cancel()
            self?.heartbeatTimer = nil
        }
        
        // Cancel keep-alive timer
        stopKeepAlive()
        
        // Cancel reconnection timer on websocket queue
        if DispatchQueue.getSpecific(key: webSocketQueueKey) != nil {
            cleanupWebSocketTimers()
        } else {
            webSocketQueue.async { [weak self] in
                self?.cleanupWebSocketTimers()
            }
        }
    }
    
    private func cleanupWebSocketTimers() {
        reconnectionTimer?.cancel()
        reconnectionTimer = nil
        connectionWatchdogTimer?.cancel()
        connectionWatchdogTimer = nil
    }
    
    private func closeConnectionForReconnect(preserveSession: Bool) {
        stateQueue.sync {
            self.isGatewayConnected = false
            self.isConnecting = false
            self.isHeartbeatActive = false
            self.shouldResume = preserveSession && self.sessionId != nil && self.sequenceNumber != nil
            
            if !preserveSession {
                self.shouldResume = false
                self.sessionId = nil
                self.resumeGatewayUrl = nil
                self.sequenceNumber = nil
            }
        }
        
        cleanupConnection()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        zlibDecompressor = zlibService()
        zlibBuffer = Data()
        
        Task { @MainActor in
            self.isConnected = false
        }
    }
    
    private func handleConnectionFailure(_ reason: String, preserveSession: Bool = true) {
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            
            var shouldReconnect = true
            self.stateQueue.sync {
                shouldReconnect = self.shouldReconnectAutomatically
            }
            
            print("WebSocket connection dropped: \(reason)")
            self.closeConnectionForReconnect(preserveSession: preserveSession)
            
            if shouldReconnect && self.isNetworkAvailable {
                self.scheduleReconnection()
            }
        }
    }
    
    private func startConnectionWatchdog() {
        connectionWatchdogTimer?.cancel()
        connectionWatchdogTimer = DispatchSource.makeTimerSource(queue: webSocketQueue)
        connectionWatchdogTimer?.schedule(deadline: .now() + 25.0)
        connectionWatchdogTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            var stillConnecting = false
            self.stateQueue.sync {
                stillConnecting = self.isConnecting
            }
            
            if stillConnecting {
                self.handleConnectionFailure("connection handshake timed out", preserveSession: true)
            }
        }
        connectionWatchdogTimer?.resume()
    }
    
    private func markGatewayConnected(didResume: Bool) {
        stateQueue.sync {
            self.isGatewayConnected = true
            self.isConnecting = false
            self.reconnectionAttempts = 0
            self.shouldResume = false
        }
        
        connectionWatchdogTimer?.cancel()
        connectionWatchdogTimer = nil
        
        Task { @MainActor in
            self.isConnected = true
            if didResume {
                await self.userService.loadMentionsFromDiscord()
            }
        }
        
        startKeepAlive()
        resyncLoadedMessages()
    }
    
    private func resyncLoadedMessages() {
        var shouldStart = false
        stateQueue.sync {
            if !self.isMessageResyncInFlight {
                self.isMessageResyncInFlight = true
                shouldStart = true
            }
        }
        
        guard shouldStart else { return }
        
        Task { [weak self] in
            guard let self = self else { return }
            defer {
                self.stateQueue.sync {
                    self.isMessageResyncInFlight = false
                }
            }
            
            let targets = await MainActor.run {
                self.userService.data.compactMap { channel -> LoadedChannelSyncTarget? in
                    let latestInMemory = channel.messages
                        .max { self.snowflakeValue($0.messageId) < self.snowflakeValue($1.messageId) }?
                        .messageId
                    let latestStored = self.userService.latestMessageId(for: channel.id)
                    
                    guard let afterMessageId = self.newerMessageId(latestInMemory, latestStored) else {
                        return nil
                    }
                    
                    return LoadedChannelSyncTarget(
                        channelId: channel.id,
                        guildId: self.guildIdForResync(channelId: channel.id, messages: channel.messages),
                        afterMessageId: afterMessageId
                    )
                }
            }
            
            guard !targets.isEmpty else { return }
            
            for target in targets {
                await self.resyncMessages(for: target)
            }
        }
    }
    
    private func resyncMessages(for target: LoadedChannelSyncTarget) async {
        var cursor = target.afterMessageId
        
        do {
            for _ in 0..<20 {
                let messages: [Message] = try await DiscordAPI.shared.makeRequest(
                    .messages,
                    args: [target.channelId, target.guildId, cursor]
                )
                
                guard !messages.isEmpty else { break }
                
                await MainActor.run {
                    self.userService.mergeMessages(messages, into: target.channelId)
                }
                
                guard let newestMessageId = messages
                    .map(\.messageId)
                    .max(by: { self.snowflakeValue($0) < self.snowflakeValue($1) }),
                      self.snowflakeValue(newestMessageId) > self.snowflakeValue(cursor)
                else { break }
                
                cursor = newestMessageId
            }
        } catch {
            print("Message resync failed for channel \(target.channelId): \(error)")
        }
    }
    
    private func guildIdForResync(channelId: String, messages: [Message]) -> String {
        if let guildId = messages.last(where: { $0.guildId != nil })?.guildId {
            return guildId
        }
        
        if let guildId = userService.guildId(containing: channelId) {
            return guildId
        }
        
        return channelId
    }
    
    private func newerMessageId(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return snowflakeValue(lhs) >= snowflakeValue(rhs) ? lhs : rhs
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }
    
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.webSocketQueue.async {
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                        
                    case .data(let data):
                        self.zlibBuffer.append(data)
                        
                        if self.zlibBuffer.count >= 4 && Array(self.zlibBuffer.suffix(4)) == [0x00, 0x00, 0xFF, 0xFF] {
                            
                            if let decompressedData = self.zlibDecompressor.decompress(self.zlibBuffer) {
                                if let fullString = String(data: decompressedData, encoding: .utf8) {
                                    self.handleMessage(fullString)
                                    
                                }
                            } else {
                                print("Zlib Decompression Failed - resetting stream")
                            }
                            
                            self.zlibBuffer.removeAll(keepingCapacity: false)
                        }
                    @unknown default:
                        print("WebSocket error, unknown")
                    }
                    self.receiveMessage()
                }
                
            case .failure(let error):
                print("WebSocket error: \(error)")
                let closeCode = self.webSocketTask?.closeCode.rawValue
                if Self.isAuthenticationFailureCloseCode(closeCode) {
                    self.handleAuthenticationFailure("gateway authentication failed with close code \(closeCode ?? -1)")
                } else {
                    self.handleConnectionFailure(error.localizedDescription, preserveSession: true)
                }
            }
        }
    }
    
    private static func isAuthenticationFailureCloseCode(_ closeCode: Int?) -> Bool {
        guard let closeCode else { return false }
        return closeCode == 4003 || closeCode == 4004
    }
    
    private func handleAuthenticationFailure(_ reason: String) {
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("WebSocket authentication failed: \(reason)")
            
            self.stateQueue.sync {
                self.shouldReconnectAutomatically = false
                self.isGatewayConnected = false
                self.isConnecting = false
                self.isHeartbeatActive = false
                self.shouldResume = false
                self.sessionId = nil
                self.resumeGatewayUrl = nil
                self.sequenceNumber = nil
            }
            
            self.cleanupConnection()
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            self.zlibDecompressor = zlibService()
            self.zlibBuffer = Data()
            
            Task { @MainActor in
                self.isConnected = false
                self.userService.clearLocalSession(reason: reason)
            }
        }
    }
    
    
    func sendJSON(_ request: [String: Any]) {
        webSocketQueue.async { [weak self] in
            guard let self = self,
                  let data = try? JSONSerialization.data(withJSONObject: request, options: []),
                  let string = String(data: data, encoding: .utf8) else {
                print("Failed to serialize JSON")
                return
            }
            
            
            
            let message = URLSessionWebSocketTask.Message.string(string)
            self.webSocketTask?.send(message) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        }
    }
    
    func getJSONfromData(data: Data) -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
    
    
    
    func scheduleReconnection() {
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Thread-safe state check
            var shouldSchedule = false
            var attempts = 0
            var isConnected = false
            var isConnecting = false
            self.stateQueue.sync {
                isConnected = self.isGatewayConnected
                isConnecting = self.isConnecting
                shouldSchedule = !isConnected && !isConnecting
                attempts = self.reconnectionAttempts
            }
            
            guard shouldSchedule else {
                if isConnected || isConnecting {
                    print("Already connected or connecting, skipping reconnection")
                }
                return
            }
            
            // Cancel any existing reconnection timer
            self.reconnectionTimer?.cancel()
            self.reconnectionTimer = nil
            
            let delay = min(pow(2.0, Double(attempts)), 60.0) // Cap at 60 seconds
            
            self.stateQueue.sync {
                self.reconnectionAttempts += 1
            }
            
            print("Attempting to reconnect in \(delay) seconds... (attempt \(self.reconnectionAttempts))")
            
            self.reconnectionTimer = DispatchSource.makeTimerSource(queue: self.webSocketQueue)
            self.reconnectionTimer?.schedule(deadline: .now() + delay)
            self.reconnectionTimer?.setEventHandler { [weak self] in
                print("Executing reconnection attempt")
                self?.reconnectionTimer?.cancel()
                self?.reconnectionTimer = nil
                self?.connect()
            }
            self.reconnectionTimer?.resume()
        }
    }
    
    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let isAvailable = (path.status == .satisfied)
            
            self.stateQueue.sync {
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = isAvailable
                
                if isAvailable && !wasAvailable {
                    print("Network restored, attempting to reconnect...")
                    // Reset reconnection attempts when network is restored
                    self.reconnectionAttempts = 0
                    
                    // Check if we should reconnect
                    if !self.isGatewayConnected && !self.isConnecting {
                        // Small delay to ensure network is fully stable
                        self.webSocketQueue.asyncAfter(deadline: .now() + 1.0) {
                            self.connect()
                        }
                    }
                } else if !isAvailable {
                    print("Network lost")
                    self.webSocketQueue.async {
                        self.closeConnectionForReconnect(preserveSession: true)
                    }
                }
            }
        }
        monitor.start(queue: networkQueue)
    }
    
    // Add a keep-alive mechanism
    private var keepAliveTimer: DispatchSourceTimer?
    
    private var keepAlivePingsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "keepAlivePingsEnabled") == nil {
            return true
        }
        
        return UserDefaults.standard.bool(forKey: "keepAlivePingsEnabled")
    }
    
    private var keepAlivePingInterval: TimeInterval {
        let interval = UserDefaults.standard.double(forKey: "keepAlivePingInterval")
        return min(max(interval > 0 ? interval : 30, 10), 300)
    }
    
    func refreshKeepAliveSettings() {
        heartbeatQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.keepAlivePingsEnabled {
                var isActive = false
                self.stateQueue.sync {
                    isActive = self.isGatewayConnected
                }
                
                if isActive {
                    self.startKeepAlive()
                }
            } else {
                self.keepAliveTimer?.cancel()
                self.keepAliveTimer = nil
            }
        }
    }
    
    private func startKeepAlive() {
        heartbeatQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.keepAliveTimer?.cancel()
            self.keepAliveTimer = nil
            
            guard self.keepAlivePingsEnabled else {
                print("Keep-alive pings disabled")
                return
            }
            
            let interval = self.keepAlivePingInterval
            
            // Send a WebSocket ping frame to keep the connection alive.
            self.keepAliveTimer = DispatchSource.makeTimerSource(queue: self.heartbeatQueue)
            self.keepAliveTimer?.schedule(deadline: .now() + interval, repeating: interval)
            
            self.keepAliveTimer?.setEventHandler { [weak self] in
                guard let self = self else { return }
                
                var isActive = false
                self.stateQueue.sync {
                    isActive = self.isGatewayConnected
                }
                
                if isActive {
                    self.webSocketTask?.sendPing { error in
                        if let error = error {
                            print("Keep-alive ping failed: \(error)")
                        } else {
                            print("Keep-alive ping sent successfully")
                        }
                    }
                } else {
                    self.keepAliveTimer?.cancel()
                    self.keepAliveTimer = nil
                }
            }
            
            self.keepAliveTimer?.resume()
        }
    }
    
    private func stopKeepAlive() {
        heartbeatQueue.async { [weak self] in
            self?.keepAliveTimer?.cancel()
            self?.keepAliveTimer = nil
        }
    }
    
    
    func handleMessage(_ string: String) {
        guard let data = string.data(using: .utf8),
              let json = getJSONfromData(data: data) else {
            print("Failed to parse message: \(string)")
            return
        }
        
        // Update sequence number if present
        if let s = json["s"] as? Int {
            stateQueue.sync {
                self.sequenceNumber = s
            }
        }
        
        if let t = json["t"] as? String {
            //print(t)
            switch t {
            case "READY":
                print("WebSocket connection ready!")
                handleReadyEvent(json: json)
                markGatewayConnected(didResume: false)
            case "USER_SETTINGS_UPDATE":
                handleUserSettingsUpdate(data)
            case "RESUMED":
                print("WebSocket session resumed successfully!")
                markGatewayConnected(didResume: true)
            case "MESSAGE_CREATE", "MESSAGE_UPDATE":
                handleChatMessage(json: json, eventType: t)
            case "MESSAGE_ACK", "READ_STATE_UPDATE":
                handleReadStateUpdate(json: json)
            case "CHANNEL_CREATE", "CHANNEL_UPDATE":
                handlePrivateChannelUpsert(json: json)
            case "CHANNEL_DELETE":
                handlePrivateChannelDelete(json: json)
            case "MESSAGE_DELETE":
                handleDeleteMessage(json: json)
            case "MESSAGE_POLL_VOTE_ADD":
                handlePollVoteEvent(json: json, isAdd: true)
            case "MESSAGE_POLL_VOTE_REMOVE":
                handlePollVoteEvent(json: json, isAdd: false)
            case "GUILD_MEMBERS_CHUNK":
                handleGuildMembersChunk(json: json)
            case "THREAD_CREATE":
                handleThreadCreate(json: json)
            case "THREAD_UPDATE":
                handleThreadUpdate(json: json)
            case "THREAD_DELETE":
                handleThreadDelete(json: json)
            case "PRESENCE_UPDATE":
                handlePresenceUpdate(json: json)
            case "SESSIONS_REPLACE":
                handleSessionReplace(json: json)
            case "TYPING_START":
                handleTypingStart(json: json)
            case "MESSAGE_REACTION_ADD", "MESSAGE_REACTION_REMOVE":
                handleMessageReaction(json: json, eventType: t)
            default:
                print("Not handled \(t)")
                break
            }
        } else if let op = json["op"] as? Int {
            switch op {
            case 10: // Hello
                handleHello(json: json)
            case 11: // Heartbeat ACK
                stateQueue.sync {
                    self.lastHeartbeatAck = true
                }
                print("Heartbeat ACK received")
            case 1: // Heartbeat request
                sendHeartbeat()
            case 7: // Reconnect
                print("Server requested reconnect")
                stateQueue.sync {
                    self.shouldResume = true // Enable resume for server-requested reconnects
                }
                closeConnectionForReconnect(preserveSession: true)
                scheduleReconnection()
            case 9: // Invalid session
                handleInvalidSession(json: json)
            default:
                print("Unhandled operation code: \(op)")
            }
        }
    }
    
    private func handleReadStateUpdate(json: [String: Any]) {
        guard let payload = json["d"] as? [String: Any] else { return }
        
        let channelId = payload["channel_id"] as? String
        ?? payload["id"] as? String
        
        let messageId = payload["message_id"] as? String
        ?? payload["last_message_id"] as? String
        ?? (payload["message_id"] as? NSNumber)?.stringValue
        ?? (payload["last_message_id"] as? NSNumber)?.stringValue
        
        guard let channelId, let messageId else { return }
        
        Task { @MainActor in
            self.userService.recordReadState(channelId: channelId, messageId: messageId)
        }
    }
    
    private func handleTypingStart(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any] else {
            print("Failed to parse typing data")
            return
        }
        
        if let typingData = try? JSONSerialization.data(withJSONObject: data) {
            let decoder = JSONDecoder()
            
            // Add this to handle 0/1 as Bool
            decoder.dataDecodingStrategy = .deferredToData
            decoder.nonConformingFloatDecodingStrategy = .throw
            
            do {
                
                let typingIndicator = try decoder.decode(Typing.self, from: typingData)
                
                if typingIndicator.member == nil {
                    print(data)
                }
                
                Task { @MainActor in
                    if self.userService.guildManager.typingIndicators[String(typingIndicator.channel_id)] == nil {
                        self.userService.guildManager.typingIndicators[String(typingIndicator.channel_id)] = []
                    }
                    
                    self.userService.guildManager.typingIndicators[String(typingIndicator.channel_id)]?.removeAll(where: { $0.user_id == typingIndicator.user_id })
                    
                    self.userService.guildManager.typingIndicators[String(typingIndicator.channel_id)]?.append(typingIndicator)
                    
                    
                    self.userService.objectWillChange.send()
                    
                    print(self.userService.guildManager.typingIndicators)
                    
                    let typing = typingIndicator
                    DispatchQueue.main.asyncAfter(deadline: .now() + 11) {
                        if let user = self.userService.guildManager.typingIndicators[String(typingIndicator.channel_id)]?.last(where: { $0.user_id == typing.user_id }) {
                            if typing.timestamp == user.timestamp {
                                self.userService.guildManager.typingIndicators[String(typingIndicator.channel_id)]?.removeAll(where: { $0.user_id == typing.user_id })
                            }
                            
                            self.userService.objectWillChange.send()
                        }
                    }
                }
                
            } catch {
                print(error)
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        
                        print("Context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        print("Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                
            }
            
        }
    }
    
    private func handleSessionReplace(json: [String: Any]) {
        guard let data = json["d"] as? [[String: Any]] else {
            print("Failed to parse session replace data")
            return
        }
        
        for data in data {
            
            if let readyData = try? JSONSerialization.data(withJSONObject: data) {
                let decoder = JSONDecoder()
                
                // Add this to handle 0/1 as Bool
                decoder.dataDecodingStrategy = .deferredToData
                decoder.nonConformingFloatDecodingStrategy = .throw
                
                do {
                    if let presence = try? decoder.decode(Presence.self, from: readyData) {
                        
                        Task { @MainActor in
                            self.userService.presenceByUserId[presence.user.id] = presence
                            
                        }
                    } else {
                        
                        let presence = try decoder.decode(PartialPresence.self, from: readyData)
                        
                        Task { @MainActor in
                            self.userService.presenceByUserId[self.userService.user?.id ?? ""] = Presence(user: self.userService.user!, status: presence.status, activities: presence.activities, clientStatus: presence.clientStatus)
                        }
                    }
                    
                } catch {
                    print(error)
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("Missing key: \(key.stringValue)")
                            print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                            
                            print("Context: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("Type mismatch for type: \(type)")
                            print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                            print("Context: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("Value not found for type: \(type)")
                            print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        case .dataCorrupted(let context):
                            print("Data corrupted")
                            print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        @unknown default:
                            print("Unknown decoding error")
                        }
                    }
                    
                }
                
            }
        }
    }
    
    private func handlePresenceUpdate(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any] else {
            print("Failed to parse Ready event data")
            return
        }
        if let readyData = try? JSONSerialization.data(withJSONObject: data) {
            let decoder = JSONDecoder()
            
            // Add this to handle 0/1 as Bool
            decoder.dataDecodingStrategy = .deferredToData
            decoder.nonConformingFloatDecodingStrategy = .throw
            
            do {
                
                let presence = try decoder.decode(Presence.self, from: readyData)
                
                Task { @MainActor in
                    self.userService.presenceByUserId[presence.user.id] = presence
                    
                }
                
            } catch {
                print(error)
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        
                        print("Context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        print("Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                
            }
            
        }
    }
    
    func subscribeToGuild(guildId: String, channelId: String? = nil) {
        var payload: [String: Any] = [
            "op": 14,  // LAZY_REQUEST / Guild Subscribe
            "d": [
                "guild_id": guildId,
                "typing": true,
                "activities": true,
                "threads": true
            ]
        ]
        
        if let channelId = channelId {
            payload["d"] = (payload["d"] as! [String: Any]).merging([
                "channels": [
                    channelId: [[0, 99]]
                ]
            ]) { $1 }
        }
        
        sendJSON(payload)
        print("Subscribed to guild: \(guildId)")
    }
    
    
    private func handleReadyEvent(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any] else {
            print("Failed to parse Ready event data")
            return
        }
        
        // ReadyEvent
        if let readyData = try? JSONSerialization.data(withJSONObject: data) {
            do {
                let decoder = JSONDecoder()
                
                decoder.dataDecodingStrategy = .deferredToData
                decoder.nonConformingFloatDecodingStrategy = .throw
                
                let readyEvent = try decoder.decode(ReadyEvent.self, from: readyData)
                DispatchQueue.main.async {
                    self.userService.user = readyEvent.user
                    self.userService.Guilds = readyEvent.guilds
                    self.userService.setDMs(readyEvent.privateChannels ?? [])
                    self.userService.readyEvent = readyEvent
                    
                    for guild in readyEvent.guilds {
                        guard let emojis = guild.emojis else { continue }
                        if self.userService.guildManager.emojis[guild.id] == nil {
                            self.userService.guildManager.emojis[guild.id] = []
                        }
                        self.userService.guildManager.emojis[guild.id]?.formUnion(emojis)
                    }
                    
                    if let mergedMembers = readyEvent.mergedMembers {
                        for (index, members) in mergedMembers.enumerated() {
                            guard let guild = readyEvent.guilds[safe: index], !members.isEmpty else { continue }
                            
                            if self.userService.guildManager.members[guild.id] == nil {
                                self.userService.guildManager.members[guild.id] = []
                            }
                            
                            self.userService.guildManager.members[guild.id]?.formUnion(members)
                        }
                    }
                    
                    for presence in readyEvent.presences {
                        self.userService.presenceByUserId[presence.user.id] = presence
                    }
                    
                    Task {
                        let readStateMap = readyEvent.readStateMap
                        await self.userService.loadMentionsFromDiscord(readStateMap: readStateMap)
                    }
                }
            } catch {
                print("Error: \(error)")
                
                
                // Better error debugging
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        
                        print("Context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        print("Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
            }
        }
        do {
            if let userSettingsData = data["user_settings"] as? [String: Any] {
                let settingsData = try JSONSerialization.data(withJSONObject: userSettingsData)
                let settings = try JSONDecoder().decode(UserSettings.self, from: settingsData)
                Task { @MainActor in
                    self.userService.userSettings = settings
                }
            } else {
                print("no user_settings found!")
                Task { @MainActor in
                    self.userService.userSettings = UserSettings()
                }
            }
            
        } catch {
            print("error parsing ready event, usersettings: \(error)")
            Task { @MainActor in
                self.userService.userSettings = UserSettings()
            }
        }
        
        // Extract session information for resumption
        if let sessionId = data["session_id"] as? String {
            stateQueue.sync {
                self.sessionId = sessionId
            }
            print("Session ID received: \(sessionId)")
        }
        
        if let resumeGatewayUrl = data["resume_gateway_url"] as? String {
            stateQueue.sync {
                self.resumeGatewayUrl = resumeGatewayUrl
            }
            print("Resume gateway URL received: \(resumeGatewayUrl)")
        }
        
    }
    
    private func handleUserSettingsUpdate(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let settingsData = json?["d"] as? [String: Any] {
                let data = try JSONSerialization.data(withJSONObject: settingsData)
                let decodedSettings = try JSONDecoder().decode(UserSettings.self, from: data)
                Task { @MainActor in
                    self.userService.userSettings = decodedSettings
                }
            }
        } catch {
            print("error parsing user settings update: \(error)")
            Task { @MainActor in
                if self.userService.userSettings == nil {
                    self.userService.userSettings = UserSettings()
                }
            }
        }
    }
    
    private func handlePrivateChannelUpsert(json: [String: Any]) {
        guard let payload = json["d"] as? [String: Any],
              let channelData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        do {
            let channel = try JSONDecoder().decode(DMs.self, from: channelData)
            DispatchQueue.main.async {
                self.userService.upsertDM(channel)
            }
        } catch {
            print("Failed to decode private channel update: \(error)")
        }
    }
    
    private func handlePrivateChannelDelete(json: [String: Any]) {
        guard let payload = json["d"] as? [String: Any],
              let channelId = payload["id"] as? String else { return }
        
        let type = payload["type"] as? Int
        DispatchQueue.main.async {
            if type == nil || type == 1 || type == 3 || self.userService.hasDMChannel(withId: channelId) {
                self.userService.removeDM(channelId: channelId)
            }
        }
    }
    
    private func handleInvalidSession(json: [String: Any]) {
        guard let data = json["d"] as? Bool else {
            print("Invalid session - no resumable flag")
            stateQueue.sync {
                self.shouldResume = false
                self.sessionId = nil
                self.resumeGatewayUrl = nil
                self.sequenceNumber = nil
            }
            closeConnectionForReconnect(preserveSession: false)
            scheduleReconnection()
            return
        }
        
        if data {
            print("Invalid session but resumable - attempting resume")
            stateQueue.sync {
                self.shouldResume = true
            }
        } else {
            print("Invalid session not resumable - full reconnect required")
            stateQueue.sync {
                self.shouldResume = false
                self.sessionId = nil
                self.resumeGatewayUrl = nil
                self.sequenceNumber = nil
            }
        }
        
        closeConnectionForReconnect(preserveSession: data)
        scheduleReconnection()
    }
    
    func requestGuildMembers(guildID: String, query: String = "", limit: Int = 100) {
        subscribeToGuild(guildId: guildID)
        let payload: [String: Any] = [
            "op": 8,
            "d": [
                "guild_id": guildID,
                "query": query,
                "limit": limit,
                "presences": true
            ]
        ]
        sendJSON(payload)
    }
    
    func sendMessageAck(channelId: String, messageId: String) {
        let payload: [String: Any] = [
            "op": 13,  // This is the internal opcode for MESSAGE_ACK used by the official client
            "d": [
                "channel_id": channelId,
                "message_id": messageId
            ]
        ]
        sendJSON(payload)
        print("Sent MESSAGE_ACK for channel \(channelId), message \(messageId)")
    }
    
    private func handleGuildMembersChunk(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any],
              let membersArray = data["members"] as? [[String: Any]],
              let guild = data["guild_id"] as? String,
              !membersArray.isEmpty else {
            return
        }
        
        let presencesArray = data["presences"] as? [[String: Any]]
        memberChunkQueue.async { [weak self] in
            guard let self = self else { return }
            autoreleasepool {
                let decoder = JSONDecoder()
                
                if let presencesArray,
                   let presenceData = try? JSONSerialization.data(withJSONObject: presencesArray, options: []),
                   let presences = try? decoder.decode([Presence].self, from: presenceData) {
                    for presence in presences {
                        self.pendingPresenceUpdates[presence.user.id] = presence
                    }
                }
                
                guard let memberData = try? JSONSerialization.data(withJSONObject: membersArray, options: []),
                      let members = try? decoder.decode([GuildMember].self, from: memberData),
                      !members.isEmpty else {
                    self.scheduleMemberFlush()
                    return
                }
                
                self.pendingMemberChunks[guild, default: []].formUnion(members)
                self.scheduleMemberFlush()
            }
        }
    }
    
    private func scheduleMemberFlush() {
        pendingMemberFlush?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushMemberChunks()
        }
        
        pendingMemberFlush = workItem
        memberChunkQueue.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    private func flushMemberChunks() {
        let memberChunks = pendingMemberChunks
        let presenceUpdates = pendingPresenceUpdates
        
        pendingMemberChunks.removeAll(keepingCapacity: true)
        pendingPresenceUpdates.removeAll(keepingCapacity: true)
        
        guard !memberChunks.isEmpty || !presenceUpdates.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for (userId, presence) in presenceUpdates {
                self.userService.presenceByUserId[userId] = presence
            }
            
            for (guild, members) in memberChunks {
                if self.userService.guildManager.members[guild] == nil {
                    self.userService.guildManager.members[guild] = members
                } else {
                    self.userService.guildManager.members[guild]?.formUnion(members)
                }
            }
        }
    }
    
    func handleDeleteMessage(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any],
              let messageID = data["id"] as? String,
              let channelID = data["channel_id"] as? String else {
            print("Failed to get message ID for deletion")
            return
        }
        
        print(data)
        
        print("Deleting message: \(messageID)")
        
        Task { @MainActor in
            self.userService.data[channelID]?.removeAll(where: { $0.messageId == messageID })
        }
    }
    
    func handleHello(json: [String: Any]) {
        guard let d = json["d"] as? [String: Any],
              let interval = d["heartbeat_interval"] as? Double else {
            print("Failed to get heartbeat interval")
            return
        }
        
        stateQueue.sync {
            self.heartbeatInterval = interval / 1000
        }
        
        print("Starting heartbeat with interval: \(heartbeatInterval)s")
        
        if shouldResume, let sessionId = sessionId, let sequenceNum = sequenceNumber {
            let payload: [String: Any] = [
                "op": 6,
                "d": [
                    "token": userService.token,
                    "session_id": sessionId,
                    "seq": sequenceNum
                ]
            ]
            print("Sending resume payload for session: \(sessionId), sequence: \(sequenceNum)")
            sendJSON(payload)
        } else {
            let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
            // Send identification payload for new connection
            let payload: [String: Any] = [
                "op": 2,
                "d": [
                    "token": userService.token,
                    "capabilities": 49153, // Removed USER_SETTINGS_PROTO (1 << 9 = 512) to get JSON instead of protobuf (ORIGINAL: 30717)
                    "properties": deviceInfo.toJson(isWebSocket: true)
                ]
            ]
            
            print("Sending identification payload for new connection")
            sendJSON(payload)
        }
        
        startHeartbeat()
    }
    
    func sendHeartbeat() {
        heartbeatQueue.async { [weak self] in
            guard let self = self else { return }
            
            var shouldSend = false
            var sequenceNum: Int?
            
            self.stateQueue.sync {
                shouldSend = self.isGatewayConnected || self.isHeartbeatActive
                sequenceNum = self.sequenceNumber
            }
            
            guard shouldSend else {
                print("Skipping heartbeat - not connected")
                return
            }
            
            let payload: [String: Any] = ["op": 1, "d": sequenceNum as Any]
            self.sendJSON(payload)
            print("Heartbeat sent with sequence: \(sequenceNum ?? -1)")
        }
    }
    
    func startHeartbeat() {
        heartbeatQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Stop any existing heartbeat
            self.heartbeatTimer?.cancel()
            self.heartbeatTimer = nil
            
            var interval: TimeInterval = 0
            self.stateQueue.sync {
                interval = self.heartbeatInterval
                self.lastHeartbeatAck = true
                self.isHeartbeatActive = true
            }
            
            guard interval > 0 else {
                print("Invalid heartbeat interval: \(interval)")
                return
            }
            
            print("Heartbeat timer started with interval: \(interval)s on dedicated thread")
            
            // Send initial heartbeat after a small delay
            self.heartbeatQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendHeartbeat()
            }
            
            // Create and start the heartbeat timer
            self.heartbeatTimer = DispatchSource.makeTimerSource(queue: self.heartbeatQueue)
            self.heartbeatTimer?.schedule(deadline: .now() + interval, repeating: interval)
            
            self.heartbeatTimer?.setEventHandler { [weak self] in
                guard let self = self else { return }
                
                var isActive = false
                var ackReceived = false
                
                self.stateQueue.sync {
                    isActive = self.isHeartbeatActive
                    ackReceived = self.lastHeartbeatAck
                }
                
                guard isActive else {
                    print("Heartbeat inactive, stopping timer")
                    self.heartbeatTimer?.cancel()
                    self.heartbeatTimer = nil
                    return
                }
                
                if ackReceived {
                    self.stateQueue.sync {
                        self.lastHeartbeatAck = false
                    }
                    self.sendHeartbeat()
                } else {
                    print("Heartbeat ACK not received, disconnecting...")
                    self.handleConnectionFailure("heartbeat ACK not received", preserveSession: true)
                }
            }
            
            self.heartbeatTimer?.resume()
        }
    }
    
    private func handleMessageUpdate(payload: [String: Any]) {
        guard let messageId = payload["id"] as? String else { return }
        
        let content = payload["content"] as? String
        let hadEditedTimestampKey = payload.keys.contains("edited_timestamp")
        let editedTimestamp: String? = payload["edited_timestamp"] is NSNull
        ? nil
        : payload["edited_timestamp"] as? String
        let embedsPayload = payload["embeds"] as? [[String: Any]]
        let attachmentsPayload = payload["attachments"] as? [[String: Any]]
        let pollPayload = payload["poll"] as? [String: Any]
        
        let decodedEmbeds = embedsPayload.flatMap { decodeEmbeds(from: $0) }
        let decodedAttachments = attachmentsPayload.flatMap { decodeAttachments(from: $0) }
        let decodedPoll = pollPayload.flatMap { decodePoll(from: $0) }
        
        Task { @MainActor in
            // Index lookup on main actor so it's always fresh
            guard
                let channelIndex = userService.data.firstIndex(where: {
                    $0.messages.contains(where: { $0.messageId == messageId })
                }),
                let msgIndex = userService.data[channelIndex].messages.firstIndex(where: {
                    $0.messageId == messageId
                })
            else { return }
            
            var updatedData = userService.data
            var message = updatedData[channelIndex].messages[msgIndex]
            
            if let content { message.content = content }
            if hadEditedTimestampKey { message.editedtimestamp = editedTimestamp }
            if let embeds = decodedEmbeds { message.embeds = embeds }
            if let attachments = decodedAttachments { message.attachments = attachments }
            if let poll = decodedPoll { message.poll = poll }
            
            
            updatedData[channelIndex].messages[msgIndex] = message
            userService.objectWillChange.send()
            userService.data = updatedData
        }
    }
    
    private func decodeEmbeds(from payload: [[String: Any]]) -> [Embed]? {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            return try JSONDecoder().decode([Embed].self, from: data)
        } catch {
            print("Error decoding embeds: \(error)")
            return nil
        }
    }
    
    private func decodeAttachments(from payload: [[String: Any]]) -> [Attachment]? {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            return try JSONDecoder().decode([Attachment].self, from: data)
        } catch {
            print("Error decoding attachments: \(error)")
            return nil
        }
    }
    
    private func decodePoll(from payload: [String: Any]) -> Poll? {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            return try JSONDecoder().decode(Poll.self, from: data)
        } catch {
            print("Error decoding poll: \(error)")
            return nil
        }
    }
    
    func updatePoll(messageId: String, mutate: @escaping (inout Poll) -> Void) {
        Task { @MainActor in
            self.userService.updateMessage(id: messageId) { message in
                guard message.poll != nil else { return }
                mutate(&message.poll!)
            }
        }
    }
    
    
    private func handlePollVoteEvent(json: [String: Any], isAdd: Bool) {
        guard let payload = json["d"] as? [String: Any],
              let channelId = payload["channel_id"] as? String,
              let messageId = payload["message_id"] as? String,
              let answerId = payload["answer_id"] as? Int else {
            return
        }
        
        let currentChannelId = userService.guildManager.currentChannel
        guard channelId == currentChannelId else { return }
        
        let userId = payload["user_id"] as? String
        
        updatePoll(messageId: messageId) { poll in
            print(poll)
            var results = poll.results ?? PollResults(isFinalized: poll.results?.isFinalized, totalVotes: 0, answerCounts: nil)
            var counts = results.answerCounts ?? []
            
            if let answers = poll.answers {
                for answer in answers where !counts.contains(where: { $0.answerId == answer.answerId }) {
                    counts.append(PollAnswerCount(answerId: answer.answerId, count: 0, meVoted: false))
                }
            }
            
            if counts.firstIndex(where: { $0.answerId == answerId }) == nil {
                counts.append(PollAnswerCount(answerId: answerId, count: 0, meVoted: false))
            }
            
            guard let index = counts.firstIndex(where: { $0.answerId == answerId }) else { return }
            
            let isCurrentUserVote = (userId == self.userService.user?.id)
            var currentCount = counts[index].count ?? 0
            let meVotedBefore = counts[index].meVoted == true
            
            if isAdd {
                if isCurrentUserVote {
                    if !meVotedBefore {
                        currentCount += 1
                    }
                    counts[index].meVoted = true
                } else {
                    currentCount += 1
                }
            } else {
                if isCurrentUserVote {
                    if meVotedBefore && currentCount > 0 {
                        currentCount = max(currentCount - 1, 0)
                    }
                    counts[index].meVoted = false
                } else {
                    if currentCount > 0 {
                        currentCount = max(currentCount - 1, 0)
                    }
                }
            }
            
            counts[index].count = currentCount
            
            results.answerCounts = counts
            results.totalVotes = counts.compactMap { $0.count }.reduce(0, +)
            poll.results = results
        }
    }
    
    private func handleThreadCreate(json: [String: Any]) {
        guard let payload = json["d"] as? [String: Any],
              let parentId = payload["parent_id"] as? String,
              let channel = decodeChannel(from: payload) else { return }
        
        Task { @MainActor in
            self.userService.upsertThread(channel, parentId: parentId)
        }
    }
    
    private func handleThreadUpdate(json: [String: Any]) {
        guard let payload = json["d"] as? [String: Any],
              let parentId = payload["parent_id"] as? String,
              let channel = decodeChannel(from: payload) else { return }
        
        Task { @MainActor in
            self.userService.upsertThread(channel, parentId: parentId)
        }
    }
    
    private func handleThreadDelete(json: [String: Any]) {
        guard let payload = json["d"] as? [String: Any],
              let parentId = payload["parent_id"] as? String,
              let threadId = payload["id"] as? String else { return }
        
        Task { @MainActor in
            self.userService.removeThread(id: threadId, parentId: parentId)
        }
    }
    
    private func decodeChannel(from payload: [String: Any]) -> Channel? {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            return try JSONDecoder().decode(Channel.self, from: data)
        } catch {
            print("Error decoding channel: \(error)")
            return nil
        }
    }
    
    private func sortThreads(_ threads: [Channel]) -> [Channel] {
        threads.sorted { lhs, rhs in
            snowflakeValue(lhs.lastMessageId ?? lhs.id) > snowflakeValue(rhs.lastMessageId ?? rhs.id)
        }
    }
    
    private func snowflakeValue(_ id: String?) -> UInt64 {
        guard let id = id, let value = UInt64(id) else { return 0 }
        return value
    }
    
    func handleMessageReaction(json: [String: Any], eventType: String) {
        guard let payload = json["d"] as? [String: Any] else { return }
        
        Task {
            do {
                let data = try JSONSerialization.data(withJSONObject: payload, options: [])
                let messageReaction = try JSONDecoder().decode(MessageReaction.self, from: data)
                await MainActor.run {
                    self.applyMessageReaction(messageReaction, isAdd: eventType == "MESSAGE_REACTION_ADD")
                }
                
            } catch {
                print(error)
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        
                        print("Context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        print("Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                    
                    print(payload)
                }
            }
        }
    }
    
    @MainActor
    private func applyMessageReaction(_ messageReaction: MessageReaction, isAdd: Bool) {
        let isCurrentUser = messageReaction.user_id == userService.user?.id
        
        userService.updateMessage(id: messageReaction.message_id) { message in
            var reactions = message.reactions ?? []
            let reactionIndex = reactions.firstIndex { reaction in
                if let id = messageReaction.emoji.id {
                    return reaction.emoji.id == id
                }
                return reaction.emoji.name == messageReaction.emoji.name
            }
            
            if let reactionIndex {
                if isAdd {
                    reactions[reactionIndex].count += 1
                    if isCurrentUser {
                        reactions[reactionIndex].me = true
                    }
                    if var countDetails = reactions[reactionIndex].count_details {
                        countDetails.normal += 1
                        reactions[reactionIndex].count_details = countDetails
                    }
                } else {
                    reactions[reactionIndex].count = max(reactions[reactionIndex].count - 1, 0)
                    if isCurrentUser {
                        reactions[reactionIndex].me = false
                    }
                    if var countDetails = reactions[reactionIndex].count_details {
                        countDetails.normal = max(countDetails.normal - 1, 0)
                        reactions[reactionIndex].count_details = countDetails
                    }
                    if reactions[reactionIndex].count == 0 {
                        reactions.remove(at: reactionIndex)
                    }
                }
            } else if isAdd {
                reactions.append(Reaction(emoji: messageReaction.emoji, count: 1, me: isCurrentUser))
            }
            
            message.reactions = reactions.isEmpty ? nil : reactions
        }
    }
    
    func handleChatMessage(json: [String: Any], eventType: String) {
        guard let payload = json["d"] as? [String: Any],
              let channelId = payload["channel_id"] as? String else { return }
        
        if eventType == "MESSAGE_UPDATE" {
            handleMessageUpdate(payload: payload)
            return
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            let decoder = JSONDecoder()
            let message = try decoder.decode(Message.self, from: data)
            Task { @MainActor in
                self.userService.rememberLatestMessageId(message.messageId, for: channelId)
                self.userService.markDMMessageReceived(channelId: channelId, messageId: message.messageId)
                
                if self.userService.data[channelId] != nil {
                    self.userService.mergeMessages([message], into: channelId)
                    self.userService.guildManager.typingIndicators[channelId]?.removeAll(where: { $0.user_id == message.author.id })
                }
                
                self.checkForMention(message: message, payload: payload)
            }
        } catch {
            print("Error decoding JSON:", error)
        }
    }
    
    @MainActor
    private func checkForMention(message: Message, payload: [String: Any]) {
        guard let currentUser = userService.user else { return }
        
        guard message.author.id != currentUser.id else { return }
        
        
        let guildId = message.guildId
        let channelId = message.channelId
        let isDMMessage = userService.hasDMChannel(withId: channelId)
        let pingAllDMs = (UserDefaults.standard.object(forKey: "pingAllDMsEnabled") as? Bool) ?? false
        
        let mentioned = message.mentioned ?? payload["mentioned"] as? Bool
        let shouldCreateMention = (isDMMessage && pingAllDMs)
        || (mentioned ?? isMentionedByStructuredFields(message: message, currentUser: currentUser))
        guard shouldCreateMention else { return }
        
        let channelName = mentionChannelName(channelId: channelId, guildId: guildId)
        
        // Resolve guild name
        let guildName: String? = guildId.flatMap { gid in
            userService.Guilds.first(where: { $0.id == gid })?.name
        }
        
        let mention = MentionItem(
            id: message.messageId,
            messageId: message.messageId,
            channelId: channelId,
            guildId: guildId,
            guildName: guildName,
            channelName: channelName,
            authorUsername: message.author.globalName ?? message.author.username,
            authorId: message.author.id,
            content: DiscordMentionFormatter.format(
                message: message,
                userSession: userService,
                style: .plain,
                linkChannels: false
            ),
            timestamp: Date()
        )
        
        userService.addMention(mention)
        handleMentionNotification(mention: mention)
    }
    
    @MainActor
    private func isMentionedByStructuredFields(message: Message, currentUser: User) -> Bool {
        if message.mentionEveryone == true { return true }
        
        if message.mentions?.contains(where: { $0.id == currentUser.id }) == true {
            return true
        }
        
        let content = message.content
        if content.contains("<@\(currentUser.id)>") || content.contains("<@!\(currentUser.id)>") {
            return true
        }
        
        guard let guildId = message.guildId,
              let mentionedRoleIds = message.mentionRoles,
              !mentionedRoleIds.isEmpty,
              let members = userService.guildManager.members[guildId],
              let member = members.first(where: { $0.user?.id == currentUser.id || $0.userId == currentUser.id }) else {
            return false
        }
        
        return !Set(member.roles).isDisjoint(with: mentionedRoleIds)
    }
    
    @MainActor
    private func mentionChannelName(channelId: String, guildId: String?) -> String {
        if let channel = resolveChannel(channelId: channelId, guildId: guildId) {
            return "#" + channel.displayName
        }
        
        if userService.hasDMChannel(withId: channelId) {
            return "DMs"
        }
        
        return "Unknown"
    }
    
    @MainActor
    private func resolveChannel(channelId: String, guildId: String?) -> Channel? {
        userService.channel(withId: channelId)
    }
    
    @MainActor
    private func handleMentionNotification(mention: MentionItem) {
        guard userService.userSettings?.status != "dnd" else { return }
        guard userService.guildManager.currentChannel != mention.channelId else { return }
        
        if isAppActive {
            guard (UserDefaults.standard.object(forKey: "foregroundPingBannersEnabled") as? Bool) ?? true else { return }
            userService.showForegroundMentionNotification(mention)
            return
        }
        
        sendMentionNotification(mention: mention)
    }
    
    private var isAppActive: Bool {
#if os(iOS)
        return UIApplication.shared.applicationState == .active
#else
        return false
#endif
    }
    
    private func sendMentionNotification(mention: MentionItem) {
        guard (UserDefaults.standard.object(forKey: "pingNotificationsEnabled") as? Bool) ?? true else { return }
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            if (UserDefaults.standard.object(forKey: "pingNotificationSoundsEnabled") as? Bool) ?? true {
                content.sound = .default
            }
            
            if let guildName = mention.guildName {
                content.title = "\(mention.authorUsername) in \(mention.channelName) · \(guildName)"
            } else {
                content.title = "\(mention.authorUsername) mentioned you in \(mention.channelName)"
            }
            
            let body = mention.content.trimmingCharacters(in: .whitespacesAndNewlines)
            content.body = body.count > 200 ? String(body.prefix(200)) + "…" : body
            
            content.userInfo = [
                "channelId": mention.channelId,
                "guildId": mention.guildId ?? "",
                "messageId": mention.messageId
            ]
            
            let request = UNNotificationRequest(
                identifier: "mention-\(mention.messageId)",
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                if let error = error {
                    print("Notification error: \(error)")
                }
            }
        }
    }
    
    deinit {
        monitor.cancel()
        disconnect()
    }
}
