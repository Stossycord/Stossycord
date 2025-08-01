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
    @Published var isNetworkAvailable: Bool = true // Network status tracking
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
    
    static var shared = WebSocketService()

    private init() {
        token = keychain.get("token") ?? ""
        currentUser = User(id: "", username: "", discriminator: "", avatar: "")
        
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        urlSession = URLSession(configuration: config)
        
        setupNetworkMonitor()
        
        if !token.isEmpty {
            connect()
        }
    }
    
    func connect() {
        token = keychain.get("token") ?? ""
        guard !token.isEmpty else {
            print("Token is empty!")
            return
        }
        
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
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectionAttempts = 0
        }
        
        // Send initial identification payload
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
        
        // Start listening for messages
        receiveMessage()
    }
    
    func disconnect() {
        reconnectionTimer?.invalidate()
        heartbeatTimer?.invalidate()
        
        if isConnected {
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let string = String(data: data, encoding: .utf8) {
                        self?.handleMessage(string)
                    }
                @unknown default:
                    break
                }
                // Continue listening for the next message
                self?.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                if self?.isNetworkAvailable == true {
                    self?.scheduleReconnection()
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
            }
        }
    }
    
    func getJSONfromData(data: Data) -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }

    func scheduleReconnection() {
        guard reconnectionAttempts < maxReconnectionAttempts else {
            print("Max reconnection attempts reached. Stopping retries.")
            return
        }
        
        let delay = pow(2.0, Double(reconnectionAttempts)) // Exponential backoff
        reconnectionAttempts += 1
        print("Attempting to reconnect in \(delay) seconds...")
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
    
    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if path.status == .satisfied {
                    print("Network is available")
                    self.isNetworkAvailable = true
                    // If previously disconnected, attempt to reconnect
                    if !self.isConnected {
                        print("Attempting to reconnect after regaining network...")
                        self.connect()
                    }
                } else {
                    print("Network is unavailable")
                    self.isNetworkAvailable = false
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func handleMessage(_ string: String) {
        guard let data = string.data(using: .utf8), let json = getJSONfromData(data: data) else { return }
        
        if let t = json["t"] as? String {
            switch t {
            case "MESSAGE_CREATE", "MESSAGE_UPDATE":
                handleChatMessage(json: json, eventType: t)
            case "MESSAGE_DELETE":
                handleDeleteMessage(json: json)
            case "GUILD_MEMBERS_CHUNK":
                handleGuildMembersChunk(json: json)
            default:
                print("Unhandled event type: \(t)")
            }
        } else if let op = json["op"] as? Int {
            switch op {
            case 10:
                handleHello(json: json)
            case 11:
                lastHeartbeatAck = true
            case 1:
                sendHeartbeat()
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
                "query": query, // Empty string fetches all members
                "limit": limit, // 0 means no limit
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
                    print("Failed to decode member: \(error) data: \(memberData)")
                    return nil
                }
            }
            
            self.currentMembers = parsedMembers
        }
    }
    
    func handleDeleteMessage(json: [String: Any]) {
        guard let data = json["d"] as? [String: Any],  let messageID = data["id"] as? String else {
            print("Failed to get message ID for deletion")
            return
        }
        
        print("Deleting message: \(messageID)")
        
        DispatchQueue.main.async {
            self.data.removeAll { $0.messageId == messageID }
        }
    }
    
    func handleHello(json: [String: Any]) {
        if let d = json["d"] as? [String: Any], let interval = d["heartbeat_interval"] as? Double {
            heartbeatInterval = interval / 1000
            startHeartbeat()
        }
    }

    func sendHeartbeat() {
        let payload: [String: Any] = ["op": 1, "d": Int(Date().timeIntervalSince1970 * 1000)]
        sendJSON(payload)
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
                self.disconnect()
            }
        }
    }
    
    func handleChatMessage(json: [String: Any], eventType: String) {
        guard let json = json["d"] as? [String: Any], let channelId = json["channel_id"] as? String, channelId == currentchannel else { return }
        
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
