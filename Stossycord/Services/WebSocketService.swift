//
//  WebSocketService.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI
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
    var heartbeatTimer: Timer?
    var lastHeartbeatAck: Bool = true
    var heartbeatInterval: TimeInterval = 0
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)

    // Reconnection properties
    private var reconnectionAttempts: Int = 0
    private var maxReconnectionAttempts: Int = 5
    private var reconnectionTimer: Timer?
    
    // Add sequence number tracking for proper Discord protocol
    private var sequenceNumber: Int?
    
    static var shared = WebSocketService()

    private init() {
        token = keychain.get("token") ?? ""
        currentUser = User(id: "", username: "", discriminator: "", avatar: "")
        
        // Configure URLSession with more lenient timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config)
        
        setupNetworkMonitor()
        
        if !token.isEmpty {
            connect()
        }
    }
    
    func connect() {
        // Don't attempt to connect if already connected or connecting
        guard !isConnected && webSocketTask == nil else {
            print("Already connected or connecting, skipping connect()")
            return
        }
        
        token = keychain.get("token") ?? ""
        guard !token.isEmpty else {
            print("Token is empty!")
            return
        }
        
        print("Starting new WebSocket connection...")
        
        // Clean up any existing connection
        disconnect()
        
        // Reset connection state
        sequenceNumber = nil
        lastHeartbeatAck = true
        
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

        guard let url = URL(string: "wss://gateway.discord.gg/?encoding=json&v=9") else {
            print("Invalid WebSocket URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("https://discord.com", forHTTPHeaderField: "Origin")
        request.setValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.maximumMessageSize = 9999999
        webSocketTask?.resume()
        
        print("WebSocket connection initiated")
        
        // Don't set isConnected = true here, wait for successful identification
        self.reconnectionAttempts = 0
        
        // Start listening for messages first
        receiveMessage()
    }
    
    func disconnect() {
        print("Disconnecting WebSocket")
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        if webSocketTask != nil {
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
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
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                
                // Only attempt reconnection if we have network and haven't exceeded max attempts
                if self.isNetworkAvailable && self.reconnectionAttempts < self.maxReconnectionAttempts {
                    self.scheduleReconnection()
                } else {
                    print("Not attempting reconnection - network: \(self.isNetworkAvailable), attempts: \(self.reconnectionAttempts)")
                }
            }
        }
    }
    
    func sendJSON(_ request: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: request, options: []),
              let string = String(data: data, encoding: .utf8) else {
            print("Failed to serialize JSON")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
                // Don't immediately disconnect on send errors
            }
        }
    }
    
    func getJSONfromData(data: Data) -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }

    func scheduleReconnection() {
        // Cancel any existing reconnection timer
        reconnectionTimer?.invalidate()
        
        guard reconnectionAttempts < maxReconnectionAttempts else {
            print("Max reconnection attempts reached. Stopping retries.")
            return
        }
        
        // Don't schedule if already connected or connecting
        guard !isConnected && webSocketTask == nil else {
            print("Already connected or connecting, skipping reconnection")
            return
        }
        
        let delay = min(pow(2.0, Double(reconnectionAttempts)), 30.0) // Cap at 30 seconds
        reconnectionAttempts += 1
        print("Attempting to reconnect in \(delay) seconds... (attempt \(reconnectionAttempts)/\(maxReconnectionAttempts))")
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            print("Executing reconnection attempt")
            self?.connect()
        }
    }
    
    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = (path.status == .satisfied)
                
                if self.isNetworkAvailable && !wasAvailable {
                    print("Network restored, attempting to reconnect...")
                    // Reset reconnection attempts when network is restored
                    self.reconnectionAttempts = 0
                    if !self.isConnected && self.webSocketTask == nil {
                        // Small delay to ensure network is fully stable
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.connect()
                        }
                    }
                } else if !self.isNetworkAvailable {
                    print("Network lost")
                    self.disconnect()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func handleMessage(_ string: String) {
        guard let data = string.data(using: .utf8),
              let json = getJSONfromData(data: data) else {
            print("Failed to parse message: \(string)")
            return
        }
        
        // Update sequence number if present
        if let s = json["s"] as? Int {
            sequenceNumber = s
        }
        
        if let t = json["t"] as? String {
            switch t {
            case "READY":
                print("WebSocket connection ready!")
                DispatchQueue.main.async {
                    self.isConnected = true
                }
            case "MESSAGE_CREATE", "MESSAGE_UPDATE":
                handleChatMessage(json: json, eventType: t)
            case "MESSAGE_DELETE":
                handleDeleteMessage(json: json)
            case "GUILD_MEMBERS_CHUNK":
                handleGuildMembersChunk(json: json)
            default:
                // Don't print for every unhandled event to reduce noise
                break
            }
        } else if let op = json["op"] as? Int {
            switch op {
            case 10: // Hello
                handleHello(json: json)
            case 11: // Heartbeat ACK
                lastHeartbeatAck = true
                print("Heartbeat ACK received")
            case 1: // Heartbeat request
                sendHeartbeat()
            case 7: // Reconnect
                print("Server requested reconnect")
                disconnect()
                scheduleReconnection()
            case 9: // Invalid session
                print("Invalid session, reconnecting...")
                disconnect()
                scheduleReconnection()
            default:
                print("Unhandled operation code: \(op)")
            }
        }
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
        
        heartbeatInterval = interval / 1000
        print("Starting heartbeat with interval: \(heartbeatInterval)s")
        
        // Send identification payload after receiving Hello
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
        sendJSON(payload)
        
        startHeartbeat()
    }

    func sendHeartbeat() {
        let payload: [String: Any] = ["op": 1, "d": sequenceNumber as Any]
        sendJSON(payload)
        print("Heartbeat sent with sequence: \(sequenceNumber ?? -1)")
    }

    func startHeartbeat() {
        heartbeatTimer?.invalidate()
        lastHeartbeatAck = true
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.lastHeartbeatAck {
                self.lastHeartbeatAck = false
                self.sendHeartbeat()
            } else {
                print("Heartbeat ACK not received, disconnecting...")
                self.disconnect()
                if self.isNetworkAvailable {
                    self.scheduleReconnection()
                }
            }
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
