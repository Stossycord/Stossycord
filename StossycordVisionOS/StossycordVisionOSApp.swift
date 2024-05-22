import SwiftUI
import Foundation
import Starscream
import KeychainSwift



struct MessageData {
    let icon: String
    var message: String
    let attachment: String
    let username: String
    let messageId: String
}

class WebSocketClient: WebSocketDelegate, ObservableObject {
    var socket: WebSocket!
    let keychain = KeychainSwift()
    var token = ""
    var currentchannel = ""
    var currentguild = ""
    @Published var messages: [String] = []
    @Published var data: [MessageData] = []
    @Published var icons: [String] = []
    @Published var usernames: [String] = []
    @Published var messageIDs: [String] = []
    @Published var attachments: [String] = []
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
            // print("WebSocket is connected:")
            let payload: [String: Any] = [
                "op": 2,
                "d": [
                    "token": self.token,
                    "capabilities": 33280,
                    "properties": [
                        "os": "Mac OS X",
                        "device": "",
                        "browser_version": "125.0",
                        "os_version": "10.15",
                    ]
                ]
            ]
            sendJSONRequest(payload)
        case .disconnected(let reason, let code):
            // print("WebSocket is disconnected: \(reason) with code: \(code)")
            getTokenAndConnect()
        case .text(let string):
            handleMessage(string)
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            socket.write(ping: Data())
            // print("ping")
        case .pong(_):
            socket.write(pong: Data())
            //print("pong")
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
            // print("Error: \(error?.localizedDescription ?? "Unknown error")")
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
        print("event recieved")
        if let data = string.data(using: .utf8),
           let json = receiveJSONResponse(data: data) {
            print("Recieved JSON") // Debug log
            if let t = json["t"] as? String {
                // print("Event type: \(t)") // Debug log
                if t == "MESSAGE_CREATE" || t == "MESSAGE_UPDATE" {
                    DispatchQueue.main.async {
                        if let d = json["d"] as? [String: Any],
                           let channelId = d["channel_id"] as? String,
                           let content = d["content"] as? String,
                           let messageid = d["id"] as? String,
                           let author = d["author"] as? [String: Any],
                           let username = author["username"] as? String,
                           let avatarHash = author["avatar"] as? String,
                           let member = d["member"] as? [String: Any],
                           let id = author["id"] as? String {
                            let avatarURL = "https://cdn.discordapp.com/avatars/\(id)/\(avatarHash).png"
                            print("username: \(username)")
                            if self.currentchannel.isEmpty {
                                // print("current channel is empty: \(self.currentchannel)")
                            } else {
                                if channelId == self.currentchannel {
                                    print("channelID: \(self.currentchannel) and Sent Message: \(string.data(using: .utf8))")
                                    if t == "MESSAGE_CREATE" {
                                        self.icons.append(avatarURL)
                                        self.usernames.append(username)
                                        self.messageIDs.append(messageid)
                                        print("\(avatarURL): \(id)")
                                        
                                        
                                        
                                        // Handle attachments
                                        var attachmentURL = ""
                                        if let attachments = d["attachments"] as? [[String: Any]] {
                                            for attachment in attachments {
                                                if let url = attachment["url"] as? String {
                                                    attachmentURL = url
                                                }
                                            }
                                        }
                                        if let nickname = member["nick"] as? String {
                                            let beans = MessageData(icon: avatarURL, message: "\(nickname): \(content)", attachment: attachmentURL, username: username, messageId: messageid)
                                            self.data.append(beans)
                                        } else if let globalname = author["global_name"] as? String {
                                            let beans = MessageData(icon: avatarURL, message: "\(globalname): \(content)", attachment: attachmentURL, username: username, messageId: messageid)
                                            self.data.append(beans)
                                        } else {
                                            let beans = MessageData(icon: avatarURL, message: "\(username): \(content)", attachment: attachmentURL, username: username, messageId: messageid)
                                            self.data.append(beans)
                                        }
                                        self.messages.append(content)
                                    } else if t == "MESSAGE_UPDATE" {
                                        if let index = self.messageIDs.firstIndex(of: messageid) {
                                            if let globalname = author["global_name"] as? String {
                                                self.messages[index] = "\(globalname): " + "\(content)"
                                            } else {
                                                self.messages[index] = "\(username ): " + "\(content)"
                                            }
                                            // Find the index in the data array
                                            if let dataIndex = self.data.firstIndex(where: { $0.messageId == messageid }) {
                                                self.data[dataIndex].message = self.messages[index]
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
                                                // Find the index in the data array
                                                if let dataIndex = self.data.firstIndex(where: { $0.messageId == messageid }) {
                                                    self.data.remove(at: dataIndex)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            print("unable to decode stuffs \(string)")
                        }
                    }
                }
            }
        }
    }
}


@main
struct YourApp: App {
    @StateObject var webSocketClient = WebSocketClient()

    var body: some Scene {
        WindowGroup {
            ContentView(webSocketClient: webSocketClient)
            // ContentSource(webSocketClient: webSocketClient)
        }
    }
}
