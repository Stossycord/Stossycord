//
//  WebSocketService.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI
import Foundation
import Starscream
import AVFoundation
import KeychainSwift
import Network

class WebSocketService: WebSocketDelegate, ObservableObject {
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
    var socket: WebSocket!
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
        currentUser = User(id: "", username: "", discriminator: "", avatar: "nil")
        
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

        var request = URLRequest(url: URL(string: "wss://gateway.discord.gg/?encoding=json&v=9")!)
        request.timeoutInterval = 10
        request.setValue("https://discord.com", forHTTPHeaderField: "Origin")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")

        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func disconnect() {
        reconnectionTimer?.invalidate()
        if isConnected {
            socket.disconnect()
            isConnected = false
        }
    }
    
    func sendJSON(_ request: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: request, options: []) {
            socket.write(data: data)
        }
    }
    
    func getJSONfromData(data: Data) -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }

    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected:
            isConnected = true
            reconnectionAttempts = 0 // Reset reconnection attempts when successfully connected
            let payload: [String: Any] = [
                "op": 2,
                "d": [
                    "token": token,
                    "capabilities": 30717,
                    "properties": [
                        "os": deviceInfo.os,
                        "device": "",
                        "browser_version": deviceInfo.browserVersion,
                        "os_version": deviceInfo.osVersion,
                    ]
                ]
            ]
            sendJSON(payload)
        case .disconnected(let reason, let code):
            print("Disconnected: \(reason), Code: \(code), reconnecting")
            if isNetworkAvailable {
                scheduleReconnection()
            }
        case .error(let error):
            print(error?.localizedDescription ?? "Unknown error")
            scheduleReconnection()
        case .text(let string):
            handleMessage(string)
        case .binary(let data):
            print(data)
        default:
            break
        }
    }
    

    func scheduleReconnection() {
        if reconnectionAttempts < maxReconnectionAttempts {
            let delay = pow(2.0, Double(reconnectionAttempts)) // Exponential backoff
            reconnectionAttempts += 1
            print("Attempting to reconnect in \(delay) seconds...")
            reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [self] _ in
                self.connect()
            }
        } else {
            print("Max reconnection attempts reached. Stopping retries.")
        }
    }
    
    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [self] path in
            DispatchQueue.main.async { [self]
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
        DispatchQueue.main.async {
            var currentmessage: MessageReference
            
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                let decoder = JSONDecoder()
                currentmessage = try decoder.decode(MessageReference.self, from: jsonData)
            } catch {
                print("Error decoding JSON:", error)
                return
            }

            self.data.removeAll { $0.messageId == currentmessage.messageId }
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
                self.socket.disconnect()
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
                    print("Handling chat message: \(currentmessage) / \(jsonData)")
                    self.data.append(currentmessage)
                }
            } else if eventType == "MESSAGE_UPDATE" {
                if let index = self.data.firstIndex(where: { $0.messageId == currentmessage.messageId }) {
                    self.data[index].content = currentmessage.content
                }
            }
        }
    }
}
