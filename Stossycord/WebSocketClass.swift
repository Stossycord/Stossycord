import SwiftUI
import Foundation
import Starscream
import KeychainSwift
import AVFoundation

struct MessageData {
    let icon: String
    var message: String
    let attachment: String
    let username: String
    let messageId: String
    let userId: String
    var replyTo: String?
}

class WebSocketClient: WebSocketDelegate, ObservableObject {
    var socket: WebSocket!
    let keychain = KeychainSwift()
    var token = ""
    var currentchannel = ""
    var currentguild = ""
    var sessionID: String?
    var voiceServerInfo: (token: String, guildID: String, endpoint: String)?
    @Published var guilds: [(name: String, id: String, icon: String?)] = []
    @Published var hasnitro: Bool = false
    @Published var hastts: Bool = false
    @Published var currentusername = ""
    @Published var currentuserid = ""
    @Published var messages: [String] = []
    @Published var data: [MessageData] = []
    @Published var icons: [String] = []
    @Published var usernames: [String] = []
    @Published var messageIDs: [String] = []
    @Published var attachments: [String] = []
    @Published var lastReadMessageID: [String: (String, String)] = [:] // Updated to hold
    var didDisconnectIntentionally = false
    @Published var isconnected = false
    @Published var isconnecedtoVC = false
    let speechSynthesizer = AVSpeechSynthesizer()
    var voiceWebSocketClient: VoiceWebSocketClient?
    
    func getcurrentchannel(input: String, guild: String) {
        currentchannel = input
        currentguild = guild
    }
    
    func disconnect() {
        if isconnected {
            didDisconnectIntentionally = true
            socket.disconnect()
            isconnected = false
            print("Successfully disconnected")
            try voiceWebSocketClient?.disconnect()
        }
    }
    
    init() {
        isconnected = false
    }
    
    func getTokenAndConnect() {
        self.token = keychain.get("token") ?? ""
        if self.token.isEmpty {
            print("Token is empty!")
            return
        }
        
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
            if !isconnected {
                isconnected = true
                print("connected? \(isconnected)")
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
            }
        case .disconnected(let reason, let code):
            getTokenAndConnect()
        case .text(let string):
            handleMessage(string)
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            socket.write(ping: Data())
        case .pong(_):
            socket.write(pong: Data())
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
        //print("event received \(self.currentuserid), \(self.hasnitro)")
        if let data = string.data(using: .utf8),
           let json = receiveJSONResponse(data: data) {
            // print("Received JSON")
            if let t = json["t"] as? String {
                if t == "MESSAGE_CREATE" || t == "MESSAGE_UPDATE"  {
                    handleChatMessage(json: json, eventType: t)
                } else if t == "MESSAGE_DELETE" {
                    handleDeleteMessage(json: json)
                } else if t == "VOICE_STATE_UPDATE" {
                    print("Voice STATE Update: " + string)
                    handleVoiceStateUpdate(json: json)
                } else if t == "VOICE_SERVER_UPDATE" {
                    print("Voice Server Update: " + string)
                    handleVoiceServerUpdate(json: json)
                } else if t == "CHANNEL_UNREAD_UPDATE" {
                    handleChannelUnreadUpdate(json: json)
                } else {
                    print("None: " + string)
                    // print("unable to decode stuffs \(string)")
                }
            }
        }
    }
    
    func handleChannelUnreadUpdate(json: [String: Any]) {
        if let d = json["d"] as? [String: Any],
           let guildId = d["guild_id"] as? String,
           let channelUpdates = d["channel_unread_updates"] as? [[String: Any]] {
            for update in channelUpdates {
                if let channelId = update["id"] as? String,
                   let lastMessageId = update["last_message_id"] as? String {
                    lastReadMessageID[channelId] = (guildId, lastMessageId)
                }
            }
        }
    }
    
    func handleChatMessage(json: [String: Any], eventType: String) {
        DispatchQueue.main.async { [self] in
            if let d = json["d"] as? [String: Any],
               let channelId = d["channel_id"] as? String,
               let content = d["content"] as? String,
               let messageid = d["id"] as? String,
               let author = d["author"] as? [String: Any],
               let username = author["username"] as? String,
               let avatarHash = author["avatar"] as? String,
               let authorid = author["id"] as? String,
               let id = author["id"] as? String {
                let avatarURL = "https://cdn.discordapp.com/avatars/\(id)/\(avatarHash).png"
                if channelId == self.currentchannel {
                    if eventType == "MESSAGE_CREATE" {
                        self.icons.append(avatarURL)
                        self.usernames.append(username)
                        self.messageIDs.append(messageid)
                        self.lastReadMessageID[channelId] = (currentguild, messageid)
                        // self.lastReadMessageID[channelId] = messageid // Update last read
                        var attachmentURL = ""
                        if let attachments = d["attachments"] as? [[String: Any]] {
                            for attachment in attachments {
                                if let url = attachment["url"] as? String {
                                    attachmentURL = url
                                }
                            }
                        }
                        
                        
                        var replyTo: String? = nil
                        if let messageReference = d["message_reference"] as? [String: Any],
                           let parentMessageId = messageReference["message_id"] as? String {
                            if let index = self.data.first(where: { $0.messageId == parentMessageId }) {
                                replyTo = "\(index.username): \(index.message)"
                            } else {
                                replyTo = "Unable to load Message"
                            }
                        }
                        
                        
                        if let member = d["member"] as? [String: Any] {
                            if let nickname = member["nick"] as? String {
                                let beans = MessageData(icon: avatarURL, message: "\(content)", attachment: attachmentURL, username: nickname, messageId: messageid, userId: authorid, replyTo: replyTo)
                                self.data.append(beans)
                            } else if let globalname = author["global_name"] as? String {
                                let beans = MessageData(icon: avatarURL, message: "\(content)", attachment: attachmentURL, username: globalname, messageId: messageid, userId: authorid, replyTo: replyTo)
                                self.data.append(beans)
                            } else {
                                let beans = MessageData(icon: avatarURL, message: "\(content)", attachment: attachmentURL, username: username, messageId: messageid, userId: authorid, replyTo: replyTo)
                                self.data.append(beans)
                            }
                        } else if let globalname = author["global_name"] as? String {
                            let beans = MessageData(icon: avatarURL, message: "\(content)", attachment: attachmentURL, username: globalname, messageId: messageid, userId: authorid, replyTo: replyTo)
                            self.data.append(beans)
                        } else {
                            let beans = MessageData(icon: avatarURL, message: "\(content)", attachment: attachmentURL, username: username, messageId: messageid, userId: authorid, replyTo: replyTo)
                            self.data.append(beans)
                        }
                        self.messages.append(content)
                        
                        if self.hastts {
                            var utterance: AVSpeechUtterance? = nil
                            if let member = d["member"] as? [String: Any] {
                                if let nickname = member["nick"] as? String {
                                    utterance = AVSpeechUtterance(string: "\(nickname) said \(content)")
                                } else if let globalname = author["global_name"] as? String {
                                    utterance = AVSpeechUtterance(string: "\(globalname) said \(content)")
                                } else {
                                    utterance = AVSpeechUtterance(string: "\(username) said \(content)")
                                }
                            } else if let globalname = author["global_name"] as? String {
                                utterance = AVSpeechUtterance(string: "\(globalname) said \(content)")
                            } else {
                                utterance = AVSpeechUtterance(string: "\(username) said \(content)")
                            }
                            if let utterance1 = utterance {
                                self.speechSynthesizer.speak(utterance1)
                            }
                        }
                    } else if eventType == "MESSAGE_UPDATE" {
                        if let index = self.messageIDs.firstIndex(of: messageid) {
                            if let globalname = author["global_name"] as? String {
                                self.messages[index] = "\(content)"
                            } else {
                                self.messages[index] = "\(content)"
                            }
                            if let dataIndex = self.data.firstIndex(where: { $0.messageId == messageid }) {
                                self.data[dataIndex].message = self.messages[index]
                            }
                        }
                    }
                }
            } else {
                print("unable to decode: \(json)")
            }
        }
    }
    
    func handleDeleteMessage(json: [String: Any]) {
        DispatchQueue.main.async {
            if let d = json["d"] as? [String: Any],
               let messageid = d["id"] as? String,
               let index = self.data.firstIndex(where: { $0.messageId == messageid }) {
                self.data.remove(at: index)
            }
        }
    }
    
    func handleVoiceStateUpdate(json: [String: Any]) {
        if let d = json["d"] as? [String: Any],
           let session_id = d["session_id"] as? String {
            self.sessionID = session_id
        }
    }
    func handleVoiceServerUpdate(json: [String: Any]) {
        DispatchQueue.main.async {
            if let d = json["d"] as? [String: Any],
               let token = d["token"] as? String,
               let guildID = d["guild_id"] as? String,
               let endpoint = d["endpoint"] as? String {
                self.voiceServerInfo = (token, guildID, endpoint)
                self.voiceWebSocketClient = VoiceWebSocketClient(endpoint: endpoint, token: token, guildID: guildID)
                self.voiceWebSocketClient?.connect()
                self.isconnecedtoVC = true
            }
        }
    }
    
    
    func connectToVoiceChannel(guildID: String, channelID: String, selfMute: Bool = false, selfDeaf: Bool = false) {
        let voiceStateUpdate: [String: Any] = [
            "op": 4,
            "d": [
                "guild_id": guildID,
                "channel_id": channelID,
                "self_mute": selfMute,
                "self_deaf": selfDeaf
            ]
        ]
        sendJSONRequest(voiceStateUpdate)
    }
}


