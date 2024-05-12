//
//  StossycordmacOSApp.swift
//  StossycordmacOS
//
//  Created by Hristos Sfikas on 12/5/2024.
//

import SwiftUI
import Foundation
import Starscream
import KeychainSwift

class WebSocketClient: WebSocketDelegate, ObservableObject {
    var socket: WebSocket!
    let keychain = KeychainSwift()
    var token = ""
    var currentchannel = ""
    var currentguild = ""
    @Published var messages: [String] = []
    @Published var icons: [String] = []
    @Published var usernames: [String] = []
    @Published var messageIDs: [String] = []
    var didDisconnectIntentionally = false
    var isconnected = false
    
    func getcurrentchannel(input: String, guild: String) {
        currentchannel = input
        currentguild = guild
    }
    
    func disconnect() {
        if isconnected {
            didDisconnectIntentionally = true
            socket.disconnect()
            print("Successfully disconnected")
        }
    }
    
    init() {
        isconnected = false
    }
    
    func getTokenAndConnect() {
        // Get token from wherever you're storing it
        self.token = keychain.get("token") ?? ""
        if self.token.isEmpty {
            print("Token is empty!")
            return
        }
        
        // Set up WebSocket connection
        var request = URLRequest(url: URL(string: "wss://gateway.discord.gg/?v=9&encoding=json")!)
        request.timeoutInterval = 10
        request.setValue("https://discord.com", forHTTPHeaderField: "Origin")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func sendJSONRequest(_ request: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: request, options: []) {
            socket.write(data: data)
        }
    }
    
    func receiveJSONResponse(data: Data) -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            isconnected = true
            print("WebSocket is connected:")
            let payload: [String: Any] = [
                "op": 2,
                "d": [
                    "token": self.token,
                    "capabilities": 16381, // This is the bitmask for all intents
                    "properties": [
                        "os": "Mac OS X",
                        "browser": "Firefox",
                        "device": "",
                        "system_locale": "en-US",
                        "browser_user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:125.0) Gecko/20100101 Firefox/125.0",
                        "browser_version": "125.0",
                        "os_version": "10.15",
                        "referrer": "",
                        "referring_domain": "",
                        "referrer_current": "https://discord.com/",
                        "referring_domain_current": "discord.com",
                        "release_channel": "stable",
                        "client_build_number": 291963,
                        "client_event_source": nil,
                        "design_id": 0
                    ],
                    "presence": [
                        "status": "unknown",
                        "since": 0,
                        "activities": [],
                        "afk": false
                    ],
                    "compress": false,
                    "client_state": [
                        "guild_versions": [:]
                    ]
                ]
            ]
            sendJSONRequest(payload)
        case .disconnected(let reason, let code):
            print("WebSocket is disconnected: \(reason) with code: \(code)")
            getTokenAndConnect()
        case .text(let string):
            handleMessage(string)
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            socket.write(ping: Data())
            print("ping")
        case .pong(_):
            socket.write(pong: Data())
            print("pong")
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            if !didDisconnectIntentionally {
                getTokenAndConnect()
            }
        case .cancelled:
            if !didDisconnectIntentionally {
                getTokenAndConnect()
            }
        case .error(let error):
            print("Error: \(error?.localizedDescription ?? "Unknown error")")
            if !didDisconnectIntentionally {
                getTokenAndConnect()
            }
        case .peerClosed:
            if !didDisconnectIntentionally {
                getTokenAndConnect()
            }
        }
    }
    
    func handleMessage(_ string: String) {
        if let data = string.data(using: .utf8),
           let json = receiveJSONResponse(data: data) {
            print("Received JSON: \(json)") // Debug log
            if let t = json["t"] as? String {
                print("Event type: \(t)") // Debug log
                if t == "MESSAGE_CREATE" || t == "MESSAGE_UPDATE" {
                    DispatchQueue.main.async {
                        if let d = json["d"] as? [String: Any],
                           let channelId = d["channel_id"] as? String,
                           let content = d["content"] as? String,
                           let messageid = d["id"] as? String,
                           let author = d["author"] as? [String: Any],
                           let username = author["username"] as? String,
                           let globalname = author["global_name"] as? String,
                           let avatarHash = author["avatar"] as? String,
                           let id = author["id"] as? String {
                            let avatarURL = "https://cdn.discordapp.com/avatars/\(id)/\(avatarHash).png"
                            if self.currentchannel.isEmpty {
                                print("current channel is empty: \(self.currentchannel)")
                            } else {
                                if channelId == self.currentchannel {
                                    print("channelID: \(self.currentchannel) and Sent Message: \(string.data(using: .utf8))")
                                    if t == "MESSAGE_CREATE" {
                                        self.icons.append(avatarURL)
                                        self.messages.append("\(globalname): " + "\(content)")
                                        self.usernames.append(username)
                                        self.messageIDs.append(messageid)
                                        print("\(avatarURL): \(id)")
                                    } else if t == "MESSAGE_UPDATE" {
                                        if let index = self.messageIDs.firstIndex(of: messageid) {
                                            self.messages[index] = "\(globalname): " + "\(content)"
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else if t == "MESSAGE_DELETE" {
                    DispatchQueue.main.async {
                        if let d = json["d"] as? [String: Any],
                           let messageid = d["id"] as? String,
                           let index = self.messageIDs.firstIndex(of: messageid) {
                            self.messageIDs.remove(at: index)
                            self.messages.remove(at: index)
                            self.usernames.remove(at: index)
                            self.icons.remove(at: index)
                        }
                    }
                }
            }
        }
    }
}


@main
struct StossycordmacOSApp: App {
    @StateObject var webSocketClient = WebSocketClient()
    var body: some Scene {
        WindowGroup {
            SidebarView(webSocketClient: webSocketClient)
        }
    }
}
