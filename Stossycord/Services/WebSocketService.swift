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

class WebSocketService: ObservableObject {
    @Published var currentUser: User
    @Published var isConnected: Bool = false
    @Published var data: [Message] = []
    @Published var channels: [Category] = []
    @Published var dms: [DMs] = []
    @Published var currentchannel: String = ""
    @Published var isNetworkAvailable: Bool = true
    @Published var Guilds: [Guild] = []
    @Published var currentguild: Guild = Guild(id: "", name: "", icon: "")
    @Published var currentroles: [AdvancedGuild.Role] = []
    @Published var currentMembers: [GuildMember] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    let keychain = KeychainSwift()
    @Published var token: String
    var deviceInfo: DeviceInfo = CurrentDeviceInfo.shared.deviceInfo
    
    // Custom threads
    private let webSocketQueue = DispatchQueue(label: "websocket.queue", qos: .utility)
    private let heartbeatQueue = DispatchQueue(label: "heartbeat.queue", qos: .utility)
    
    // Heartbeat properties
    private var heartbeatTimer: DispatchSourceTimer?
    private var lastHeartbeatAck: Bool = true
    private var heartbeatInterval: TimeInterval = 0
    private var isHeartbeatActive: Bool = false
    
    private let monitor = NWPathMonitor()
    private let networkQueue = DispatchQueue.global(qos: .background)

    // Reconnection properties
    private var reconnectionAttempts: Int = 0
    private var maxReconnectionAttempts: Int = 5
    private var reconnectionTimer: DispatchSourceTimer?
    private var isConnecting: Bool = false
    
    // Add sequence number tracking for proper Discord protocol
    private var sequenceNumber: Int?
    
    // Session resumption properties
    private var sessionId: String?
    private var resumeGatewayUrl: String?
    private var shouldResume: Bool = false
    
    // Thread safety
    private let stateQueue = DispatchQueue(label: "websocket.state", qos: .utility)
    
    static var shared = WebSocketService()

    private init() {
        token = keychain.get("token") ?? ""
        currentUser = User(id: "", username: "", discriminator: "", avatar: "")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        urlSession = URLSession(configuration: config)
        
        setupNetworkMonitor()
        
        if !token.isEmpty {
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
                shouldConnect = !self.isConnected && !self.isConnecting
            }
            
            guard shouldConnect else {
                print("Already connected or connecting, skipping connect()")
                return
            }
            
            let token = self.keychain.get("token") ?? ""
            guard !token.isEmpty else {
                print("Token is empty!")
                return
            }
            
            print("Starting new WebSocket connection on custom thread...")
            
            // Set connecting state first, then clean up
            self.stateQueue.sync {
                self.isConnecting = true
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
            
            // Fetch user and guilds on background thread
            CurrentUser(token: token) { user in
                DispatchQueue.main.async {
                    if let user {
                        self.currentUser = user
                    } else {
                        print("Unable to get User")
                    }
                }
            }
            
            getDiscordGuilds(token: token) { result in
                DispatchQueue.main.async {
                    self.Guilds = result
                }
            }

            // Use resume URL if available, otherwise use standard gateway
            let gatewayUrl: String
            if self.shouldResume, let resumeUrl = self.resumeGatewayUrl {
                gatewayUrl = resumeUrl
            } else {
                gatewayUrl = "wss://gateway.discord.gg/?encoding=json&v=9"
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
            request.setValue(self.deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("websocket", forHTTPHeaderField: "Upgrade")
            request.setValue("Upgrade", forHTTPHeaderField: "Connection")
            request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
            request.setValue("discord-client", forHTTPHeaderField: "Sec-WebSocket-Protocol")
            request.timeoutInterval = 60
            
            self.webSocketTask = self.urlSession.webSocketTask(with: request)
            self.webSocketTask?.maximumMessageSize = 9999999
            self.webSocketTask?.resume()
            
            print("WebSocket connection initiated on custom thread")
            
            self.stateQueue.sync {
                self.reconnectionAttempts = 0
            }
            
            self.receiveMessage()
        }
    }
    
    func disconnect() {
        print("Disconnecting WebSocket")
        
        stateQueue.sync {
            self.isConnecting = false
            self.isHeartbeatActive = false
        }
        
        self.cleanupConnection()
        
        DispatchQueue.main.async {
            self.isConnected = false
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
        webSocketQueue.async { [weak self] in
            self?.reconnectionTimer?.cancel()
            self?.reconnectionTimer = nil
        }
        
        if webSocketTask != nil {
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            // Process messages on the websocket queue
            self.webSocketQueue.async {
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let string = String(data: data, encoding: .utf8) {
                            self.handleMessage(string)
                        }
                    @unknown default:
                        break
                    }
                    // Continue listening for the next message
                    self.receiveMessage()
                    
                case .failure(let error):
                    print("WebSocket receive error: \(error)")
                    
                    // Handle specific error types
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain {
                        switch nsError.code {
                        case NSURLErrorTimedOut:
                            print("Connection timed out - network may be slow or unstable")
                        case NSURLErrorNetworkConnectionLost:
                            print("Network connection lost")
                        case NSURLErrorNotConnectedToInternet:
                            print("No internet connection")
                        case NSURLErrorCannotConnectToHost:
                            print("Cannot connect to Discord servers")
                        default:
                            print("Network error: \(nsError.localizedDescription)")
                        }
                    }
                    
                    self.stateQueue.sync {
                        self.isHeartbeatActive = false
                    }
                    
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.isConnecting = false
                    }
                    
                    self.webSocketTask = nil
                    
                    // Check if we should attempt reconnection
                    var shouldReconnect = false
                    self.stateQueue.sync {
                        shouldReconnect = self.isNetworkAvailable && self.reconnectionAttempts < self.maxReconnectionAttempts
                    }
                    
                    if shouldReconnect {
                        // Add a longer delay for timeout errors
                        let extraDelay: TimeInterval = nsError.code == NSURLErrorTimedOut ? 5.0 : 0.0
                        self.webSocketQueue.asyncAfter(deadline: .now() + extraDelay) {
                            // Enable resume for network-related disconnects
                            self.stateQueue.sync {
                                if self.sessionId != nil && self.resumeGatewayUrl != nil {
                                    self.shouldResume = true
                                }
                            }
                            self.scheduleReconnection()
                        }
                    } else {
                        print("Not attempting reconnection - network: \(self.isNetworkAvailable), attempts: \(self.reconnectionAttempts)")
                    }
                }
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
            self.stateQueue.sync {
                shouldSchedule = !self.isConnected && !self.isConnecting && self.reconnectionAttempts < self.maxReconnectionAttempts
                attempts = self.reconnectionAttempts
            }
            
            guard shouldSchedule else {
                if self.isConnected || self.isConnecting {
                    print("Already connected or connecting, skipping reconnection")
                } else {
                    print("Max reconnection attempts reached. Stopping retries.")
                }
                return
            }
            
            // Cancel any existing reconnection timer
            self.reconnectionTimer?.cancel()
            self.reconnectionTimer = nil
            
            let delay = min(pow(2.0, Double(attempts)), 30.0) // Cap at 30 seconds
            
            self.stateQueue.sync {
                self.reconnectionAttempts += 1
            }
            
            print("Attempting to reconnect in \(delay) seconds... (attempt \(self.reconnectionAttempts)/\(self.maxReconnectionAttempts))")
            
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
                    if !self.isConnected && !self.isConnecting {
                        // Small delay to ensure network is fully stable
                        self.webSocketQueue.asyncAfter(deadline: .now() + 1.0) {
                            self.connect()
                        }
                    }
                } else if !isAvailable {
                    print("Network lost")
                    self.disconnect()
                }
            }
        }
        monitor.start(queue: networkQueue)
    }
    
    // Add a keep-alive mechanism
    private var keepAliveTimer: DispatchSourceTimer?
    
    private func startKeepAlive() {
        heartbeatQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.keepAliveTimer?.cancel()
            self.keepAliveTimer = nil
            
            // Send a ping every 30 seconds to keep connection alive
            self.keepAliveTimer = DispatchSource.makeTimerSource(queue: self.heartbeatQueue)
            self.keepAliveTimer?.schedule(deadline: .now() + 30.0, repeating: 30.0)
            
            self.keepAliveTimer?.setEventHandler { [weak self] in
                guard let self = self else { return }
                
                var isActive = false
                self.stateQueue.sync {
                    isActive = self.isConnected
                }
                
                if isActive {
                    // Send a WebSocket ping frame to keep connection alive
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
            switch t {
            case "READY":
                print("WebSocket connection ready!")
                handleReadyEvent(json: json)
                stateQueue.sync {
                    self.isConnecting = false
                    self.shouldResume = false // Reset resume flag after successful connect
                }
                DispatchQueue.main.async {
                    self.isConnected = true
                }
                // Start keep-alive mechanism
                startKeepAlive()
            case "RESUMED":
                print("WebSocket session resumed successfully!")
                stateQueue.sync {
                    self.isConnecting = false
                    self.shouldResume = false // Reset resume flag after successful resume
                }
                DispatchQueue.main.async {
                    self.isConnected = true
                }
                // Start keep-alive mechanism
                startKeepAlive()
            case "MESSAGE_CREATE", "MESSAGE_UPDATE":
                handleChatMessage(json: json, eventType: t)
            case "MESSAGE_DELETE":
                handleDeleteMessage(json: json)
            case "GUILD_MEMBERS_CHUNK":
                handleGuildMembersChunk(json: json)
            default:
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
                disconnect()
                scheduleReconnection()
            case 9: // Invalid session
                handleInvalidSession(json: json)
            default:
                print("Unhandled operation code: \(op)")
            }
        }
    }

    private func handleReadyEvent(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any] else {
            print("Failed to parse Ready event data")
            return
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
    
    private func handleInvalidSession(json: [String: Any]) {
        guard let data = json["d"] as? Bool else {
            print("Invalid session - no resumable flag")
            stateQueue.sync {
                self.shouldResume = false
                self.sessionId = nil
                self.resumeGatewayUrl = nil
                self.sequenceNumber = nil
            }
            disconnect()
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
        
        disconnect()
        scheduleReconnection()
    }
    
    func requestGuildMembers(guildID: String, query: String = "", limit: Int = 0) {
        let payload: [String: Any] = [
            "op": 8,
            "d": [
                "guild_id": guildID,
                "query": query,
                "limit": limit,
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
              let members = data["members"] as? [[String: Any]] else {
            return
        }
        
        DispatchQueue.main.async {
            let parsedMembers = members.compactMap { memberData -> GuildMember? in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: memberData, options: [])
                    let decoder = JSONDecoder()
                    return try decoder.decode(GuildMember.self, from: jsonData)
                } catch {
                    print("Failed to decode member: \(error)")
                    return nil
                }
            }
            
            self.currentMembers = parsedMembers
        }
    }
    
    func handleDeleteMessage(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any],
              let messageID = data["id"] as? String else {
            print("Failed to get message ID for deletion")
            return
        }
        
        print("Deleting message: \(messageID)")
        
        DispatchQueue.main.async {
            self.data.removeAll { $0.messageId == messageID }
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
                    "token": token,
                    "session_id": sessionId,
                    "seq": sequenceNum
                ]
            ]
            print("Sending resume payload for session: \(sessionId), sequence: \(sequenceNum)")
            sendJSON(payload)
        } else {
            // Send identification payload for new connection
            let payload: [String: Any] = [
                "op": 2,
                "d": [
                    "token": token,
                    "capabilities": 30717,
                    "properties": [
                        "os": deviceInfo.os,
                        "device": deviceInfo.device,
                        "browser_version": deviceInfo.browserVersion,
                        "os_version": deviceInfo.osVersion,
                    ]
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
                shouldSend = self.isConnected || self.isHeartbeatActive
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
                    self.disconnect()
                    
                    if self.isNetworkAvailable {
                        self.scheduleReconnection()
                    }
                }
            }
            
            self.heartbeatTimer?.resume()
        }
    }
    
    func handleChatMessage(json: [String: Any], eventType: String) {
        guard let json = json["d"] as? [String: Any],
              let channelId = json["channel_id"] as? String,
              channelId == currentchannel else { return }
        
        var currentmessage: Message
        var jsonData: Data = Data()
        
        do {
            jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
            let decoder = JSONDecoder()
            currentmessage = try decoder.decode(Message.self, from: jsonData)
        } catch {
            print("Error decoding JSON:", error)
            return
        }
        
        DispatchQueue.main.async {
            if eventType == "MESSAGE_CREATE" {
                if self.currentchannel == currentmessage.channelId {
                    print("Handling chat message: \(currentmessage)")
                    self.data.append(currentmessage)
                }
            } else if eventType == "MESSAGE_UPDATE" {
                if let index = self.data.firstIndex(where: { $0.messageId == currentmessage.messageId }) {
                    self.data[index].content = currentmessage.content
                }
            }
        }
    }
    
    deinit {
        monitor.cancel()
        disconnect()
    }
}
