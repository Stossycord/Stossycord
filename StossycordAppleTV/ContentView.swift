//
//  ContentView.swift
//  Stossy11DIscord
//
//  Created by Hristos on 4/5/2024.
//


import Foundation
import SwiftUI
import KeychainSwift
import Giffy

// let user = DiscordREST()
struct Message: Identifiable {
    let id: String
}

struct Guild {
    let id: String
    let name: String
}



struct ChannelView: View {
    @AppStorage("ISOpened") var hasbeenopened = true
    @State var text = ""
    // @State var token = ""
    @State var imageurl2 = ""
    let channelid: String
    @State var selectedMessage: Message? = nil
    @ObservedObject var webSocketClient: WebSocketClient
    let keychain = KeychainSwift()
    let token: String
    @State private var translation = ""
    var body: some View {
            VStack {
                ScrollView {
                    ForEach(Array(zip(zip(webSocketClient.icons, webSocketClient.messages), zip(webSocketClient.usernames, webSocketClient.messageIDs))), id: \.0.1) { iconMessage, usernameMessageId in
                        let (icon, message) = iconMessage
                        let (username, messageId) = usernameMessageId
                        HStack {
                            AsyncImage(url: URL(string: icon)) { image in
                                image.resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .contextMenu {
                                        if username == "someonethatexists1234567890" {
                                            Button(action: {
                                                self.selectedMessage = Message(id: messageId)
                                            }) {
                                                Text("Delete")
                                            }
                                        }
                                    }
                            } placeholder: {
                                ProgressView()
                            }
                            
                           //  let pattern = "<:(.*):(\\d*)>"
                            let gifEmojiPattern = "<a:(.*):(\\d*)>"
                            let userIdPattern = "<@(\\d*)>"
                            let emojiPattern = "<:(.*):(\\d*)>"

                            let userIdRegex = try? NSRegularExpression(pattern: userIdPattern)
                            let emojiRegex = try? NSRegularExpression(pattern: emojiPattern)
                            let animatedEmojiRegex = try? NSRegularExpression(pattern: gifEmojiPattern)

                            let range = NSRange(location: 0, length: message.utf16.count)

                            let userIdMatch = userIdRegex?.firstMatch(in: message, options: [], range: range)
                            let emojiMatch = emojiRegex?.firstMatch(in: message, options: [], range: range)
                            let animatedEmojiMatch = animatedEmojiRegex?.firstMatch(in: message, options: [], range: range)

                            if userIdMatch == nil && emojiMatch == nil && animatedEmojiMatch == nil {
                                Text(LocalizedStringKey(message))
                            } else {
                                // Process user IDs
                                if let match = userIdMatch {
                                    if let userIdRange = Range(match.range(at: 1), in: message) {
                                        let userId = String(message[userIdRange])
                                        MessageView(message: message, isEmoji: "userid", token: token)
                                    }
                                }

                                // Process static emojis
                                if let match = emojiMatch {
                                    if let emojiRange = Range(match.range(at: 2), in: message) {
                                        let emojiId = String(message[emojiRange])
                                        MessageView(message: message, isEmoji: "yes", token: token)
                                    }
                                }

                                // Process animated emojis
                                if let match = animatedEmojiMatch {
                                    if let animatedEmojiRange = Range(match.range(at: 2), in: message) {
                                        let animatedEmojiId = String(message[animatedEmojiRange])
                                        MessageView(message: message, isEmoji: "no", token: token)
                                    }
                                }
                            }


                            
                            /* AsyncImage(url: URL(string: imageurl2)) { image in
                                image.resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } placeholder: {
                                //
                            }
                             */
                        }
                        
                    }
                }
                HStack {
                    TextField("Message #off-topic", text: $text)
                        .onSubmit {
                            sendPostRequest(content: text, token: token, channel: channelid)
                            text = ""
                        }
                    Button("relogin") {
                        keychain.set("", forKey: "token")
                        hasbeenopened = true
                    }
                }
            }
            .padding()
            .alert(item: $selectedMessage) { message in
                Alert(
                    title: Text("Delete Message"),
                    message: Text("Are you sure you want to delete this message?"),
                    primaryButton: .destructive(Text("Delete")) {
                        // Call your DELETE request method here with message.id
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear() {
                webSocketClient.getcurrentchannel(input: channelid)
                webSocketClient.getTokenAndConnect()
            }
        }
}



/* struct SheetView: View {
    @AppStorage("ISOpened") var hasbeenopened = true
    @State private var token = ""
    private var isdisabled = true
    @Environment(\.dismiss) var dismiss
    var body: some View {
        Text("")
        Text("Welcome to StossyCord it is a custom Discord Client")
            .font(.title)
        // WebView(url: URL(string: "https://discord.com/login")!)
        Button("Continue") {
            let keychain = KeychainSwift()
            token = keychain.get("token") ?? ""
            if token == "" {
                // do nothing
            } else {
                hasbeenopened = false
                dismiss()
            }
        }
        .padding()
        // .disabled(true)
    }
}
*/


struct ContentView: View {
    @ObservedObject var webSocketClient: WebSocketClient
    @AppStorage("ISOpened") var hasbeenopened = true
    @State private var guilds: [(name: String, id: String, icon: String?)] = []
    @State var token = ""
    @State var searchTerm = ""
    let keychain = KeychainSwift()

    var body: some View {
        let keychain = KeychainSwift()
        NavigationStack {
            VStack {
                Text("")
                    .font(.title)
                    .onTapGesture {
                        hasbeenopened = true
                    }
                    .onAppear() {
                        // let keychain = KeychainSwift()
                        token = keychain.get("token") ?? ""
                        if token == "" {
                            hasbeenopened = true
                        }
                        webSocketClient.getcurrentchannel(input: "")
                        webSocketClient.messages = []
                        webSocketClient.messageIDs = []
                        webSocketClient.usernames = []
                        webSocketClient.disconnect()
                    }
                List {
                    ForEach(guilds.filter { guild in
                        searchTerm.isEmpty || guild.name.lowercased().contains(searchTerm.lowercased())
                    }, id: \.id) { guild in
                        NavigationLink {
                            // ChannelView(webSocketClient: webSocketClient, token: token)
                            ServerView(webSocketClient: webSocketClient, token: token, serverId: guild.id)
                        } label: {
                            HStack {
                                if guild.icon != nil {
                                    AsyncImage(url: URL(string: guild.icon!)) { image in
                                        image.resizable()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        ProgressView()
                                    }
                                }
                                // AsyncImage(url: URL(string: guild.icon!))
                                Text(guild.name)
                                    
                            }
                        }
                        .onAppear() {
                            webSocketClient.getcurrentchannel(input: "")
                        }
                        
                        /* Button(action: {
                         print("Guild ID: \(guild.id)")
                         }) {
                         Text(guild.name)
                         }
                         */
                    }
                }.navigationTitle("Servers:")
                    .searchable(text: $searchTerm)
            }.onAppear {
                token = keychain.get("token") ?? ""
                if !token.isEmpty {
                    getDiscordGuilds(token: token) { fetchedGuilds in
                        self.guilds = fetchedGuilds
                    }
                }
            }
            .sheet(isPresented: $hasbeenopened) {
                LoginView()
            }
        }
    }
    public func SetGuilds() {
        token = keychain.get("token") ?? ""
        if !token.isEmpty {
            getDiscordGuilds(token: token) { fetchedGuilds in
                self.guilds = fetchedGuilds
            }
        }
    }
}

struct ServerView: View {
    @ObservedObject var webSocketClient: WebSocketClient
    let token: String
    let serverId: String
    @State private var items: [Item] = []

    var body: some View {
        VStack {
            List(items) { item in
                if !item.name.starts(with: "#") {
                    Text(item.name)
                } else {
                    NavigationLink {
                        ChannelView(channelid: item.id, webSocketClient: webSocketClient, token: token)
                    } label: {
                        Text(item.name)
                    }
                }
            }
        }
        .onAppear() {
            webSocketClient.getcurrentchannel(input: "")
            webSocketClient.messages = []
            webSocketClient.messageIDs = []
            webSocketClient.usernames = []
            webSocketClient.disconnect()
            getDiscordChannels(serverId: serverId, token: token) { items in
                self.items = items
            }
        }
    }
    func getDiscordChannels(serverId: String, token: String, completion: @escaping ([Item]) -> Void) {
        guard let url = URL(string: "https://discord.com/api/v9/guilds/\(serverId)/channels?channel_limit=100") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")
        request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
        request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
        request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
        request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
        request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
            } else if let data = data {
                do {
                    print("MAYO BEANS: aaaa\(String(data: data, encoding: .utf8) ?? ""))aaaa")
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        var items: [Item] = []
                        var currentHeading: String? = nil
                        for dict in jsonArray {
                            if let name = dict["name"] as? String, let type = dict["type"] as? Int, let id = dict["id"] as? String, let position = dict["position"] as? Int {
                                let item = Item(id: id, name: type == 0 ? "# " + name : name, heading: currentHeading, position: position)
                                items.append(item)
                            }
                        }
                        // Sort the items based on the position
                        items.sort { $0.position < $1.position }
                        DispatchQueue.main.async {
                            completion(items)
                        }
                    }
                } catch {
                    print("Error: \(error)")
                }
            }
        }

        task.resume()
    }

    struct Item: Identifiable {
        let id: String
        let name: String
        let heading: String?
        let position: Int
    }
}




struct MessageView: View {
    let message: String
    let isEmoji: String
    let token: String
    @State private var username: String = ""
    let keychain = KeychainSwift()

    var body: some View {
        print(message)
        let userIdPattern = "<@(\\d*)>"
        let emojiPattern = "<:(.*):(\\d*)>"
        let gifemojipattern = "<a:(.*):(\\d*)>"
        let userIdRegex = try? NSRegularExpression(pattern: userIdPattern)
        let emojiRegex = try? NSRegularExpression(pattern: emojiPattern)
        let emoji2Regex = try? NSRegularExpression(pattern: gifemojipattern)
        let nsString = message as NSString
        let userIdMatches = userIdRegex?.matches(in: message, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        let emojiMatches = emojiRegex?.matches(in: message, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        let GifemojiMatches = emoji2Regex?.matches(in: message, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        var lastEnd = message.startIndex
        var views: [AnyView] = []
        
        switch isEmoji {
        case "yes":
            for match in emojiMatches {
                let range = Range(match.range, in: message)!
                let textRange = lastEnd..<range.lowerBound
                let text = String(message[textRange])
                var emojiId = String(message[range]).components(separatedBy: ":").last ?? ""
                emojiId = String(emojiId.dropLast())
                let imageUrl = "https://cdn.discordapp.com/emojis/\(emojiId).png?size=96"
                
                views.append(AnyView(Text(text)))
                views.append(AnyView(AsyncImage(url: URL(string: imageUrl)) { image in
                    image.resizable()
                         .frame(width: 32, height: 32)
                         .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                        .onAppear() {
                            print(emojiId)
                            print(imageUrl)
                        }
                }))
                lastEnd = range.upperBound
            }
        case "no":
            for match in GifemojiMatches {
                let range = Range(match.range, in: message)!
                let textRange = lastEnd..<range.lowerBound
                let text = String(message[textRange])
                var emojiId = String(message[range]).components(separatedBy: ":").last ?? ""
                emojiId = String(emojiId.dropLast())
                let imageUrl = "https://cdn.discordapp.com/emojis/\(emojiId).gif?size=96"
                let url = URL(string: imageUrl)
                
                views.append(AnyView(Text(text)))
                views.append(AnyView(AsyncGiffy(url: url!) { phase in
                    switch phase {
                    case .loading:
                        ProgressView()
                    case .error:
                        Text("Failed to load GIF")
                    case .success(let giffy):
                        giffy
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .onAppear() {
                                print("giffff")
                            }
                    }
                }))
                lastEnd = range.upperBound
            }
        case "userid":
            for match in userIdMatches {
                print("test123456789")
                let range = Range(match.range, in: message)!
                let textRange = lastEnd..<range.lowerBound
                let text = String(message[textRange])
                var userId = String(message[range]).dropFirst(2).dropLast()
                    getUsernameFromDiscord(userId: String(userId), token: token) { result in
                        DispatchQueue.main.async {
                            print("JSON EEEE: \(result ?? "")")
                            self.username = "@" + result! ?? ""
                        }
                    }
                
                views.append(AnyView(Text(text)))
                views.append(AnyView(Text(username)))
                lastEnd = range.upperBound
            }
        default:
            views.append(AnyView(Text(message)))
        }
        
        return HStack {
            ForEach(views.indices, id: \.self) { index in
                views[index]
            }
        }
    }
    
    func getUsernameFromDiscord(userId: String, token: String, completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://discord.com/api/v9/users/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")
        request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
        request.addValue("https://discord.com/channels/949183273383395328/958116619706564668", forHTTPHeaderField: "Referer")
        request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
        request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
        request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
        request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                completion(nil)
            } else if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let username = json["username"] as? String {
                        completion(username)
                        print("Username Aquired: " + username)
                    } else {
                        print("Invalid JSON")
                        completion(nil)
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}





// https://discord.com/api/v9/channels/1119174763651272786/messages?limit=50

func sendPostRequest(content: String, token: String, channel: String) {
    let url = URL(string: "https://discord.com/api/v9/channels/\(channel)/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    // Headers
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(token, forHTTPHeaderField: "Authorization")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("https://discord.com/channels/949183273383395328/958116619706564668", forHTTPHeaderField: "Referer")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")


    // JSON Body
    let bodyObject: [String: Any] = ["content": content]
    request.httpBody = try? JSONSerialization.data(withJSONObject: bodyObject)

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            let str = String(data: data, encoding: .utf8)
            print("Received data:\n\(str ?? "")")
        }
    }

    task.resume()
}
func getDiscordGuilds(token: String, completion: @escaping ([(name: String, id: String, icon: String?)]) -> Void) {
    let url = URL(string: "https://discord.com/api/v9/users/@me/guilds")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(token, forHTTPHeaderField: "Authorization")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("https://discord.com/channels/949183273383395328/958116619706564668", forHTTPHeaderField: "Referer")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")
    // ... rest of your headers ...

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    let guilds = jsonArray.compactMap { dict in
                        if let name = dict["name"] as? String, let id = dict["id"] as? String {
                            let icon = dict["icon"] as? String
                            let iconUrl = icon != nil ? "https://cdn.discordapp.com/icons/\(id)/\(icon!).png" : nil
                            return (name: name, id: id, icon: iconUrl)
                        }
                        return nil
                    }
                    completion(guilds)
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }

    task.resume()
}


func getDiscordGuildsold(token: String, completion: @escaping ([(name: String, id: String)]) -> Void) {
    let url = URL(string: "https://discord.com/api/v9/users/@me/guilds")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(token, forHTTPHeaderField: "Authorization")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("https://discord.com/channels/949183273383395328/958116619706564668", forHTTPHeaderField: "Referer")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    let guilds = jsonArray.compactMap { dict in
                        if let name = dict["name"] as? String, let id = dict["id"] as? String {
                            return (name: name, id: id)
                        }
                        return nil
                    }
                    completion(guilds)
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }

    task.resume()
}


