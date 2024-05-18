//
//  ContentView.swift
//  Stossy11DIscord
//
//  Created by Hristos Sfikas on 4/5/2024.
//


import Foundation
import SwiftUI
import KeychainSwift
import Giffy

// let user = DiscordREST()


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
    @State var username = ""
    @State var searchTerm = ""
    let keychain = KeychainSwift()

    var body: some View {
        let keychain = KeychainSwift()
        NavigationView {
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
                        webSocketClient.getcurrentchannel(input: "", guild: "")
                        webSocketClient.data = []
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
                            ServerView(webSocketClient: webSocketClient, token: token, username: username, serverId: guild.id)
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
                            webSocketClient.getcurrentchannel(input: "", guild: "")
                        }
                        
                        /* Button(action: {
                         print("Guild ID: \(guild.id)")
                         }) {
                         Text(guild.name)
                         }
                         */
                    }
                }.navigationTitle("Servers:")
                    .toolbar {
                        // Adds an item in the toolbar
                        ToolbarItem {
                            // Example with a button
                            NavigationLink {
                                DMa(webSocketClient: webSocketClient, token: token, username: username)
                            } label: {
                                Text("DMs")
                            }

                        }
                    }
                    .searchable(text: $searchTerm)
            }.onAppear {
                token = keychain.get("token") ?? ""
                if !token.isEmpty {
                    getDiscordUsername(token: token) { fetchedUsername in
                        self.username = fetchedUsername
                    }
                    getDiscordGuilds(token: token) { fetchedGuilds in
                        self.guilds = fetchedGuilds
                    }
                }
            }
            .sheet(isPresented: $hasbeenopened) {
                LoginView()
            }
        }
        .navigationViewStyle(.stack)
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

func getDiscordUsername(token: String, completion: @escaping (String) -> Void) {
    let url = URL(string: "https://discord.com/api/v9/users/@me")!
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
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let username = json["username"] as? String {
                        completion(username)
                    }
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }

    task.resume()
}



struct ServerView: View {
    @ObservedObject var webSocketClient: WebSocketClient
    let token: String
    let username: String
    let serverId: String
    @State private var items: [Item] = []

    var body: some View {
        VStack {
            List {
                ForEach(items) { item in
                    if item.type == 4 { // This is a heading
                        Text(item.name)
                            .font(.headline)
                            .padding(.top)
                    } else if item.name.starts(with: "#") { // This is a channel
                        VStack {
                            NavigationLink {
                                ChannelView(channelid: item.id, webSocketClient: webSocketClient, token: token, guild: serverId, channelname: item.name, username: username)
                            } label: {
                                Text(item.name)
                            }
                        }
                    }
                }
            }
        }
        .onAppear() {
            webSocketClient.getcurrentchannel(input: "", guild: "")
            webSocketClient.data = []
            webSocketClient.messageIDs = []
            webSocketClient.icons = []
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
                                if type == 4 { // This is a category
                                    currentHeading = name
                                } else { // This is a channel
                                    let item = Item(id: id, name: type == 0 ? "# " + name : name, heading: currentHeading, type: type, position: position)
                                    items.append(item)
                                }
                            }
                        }
                        // Sort the items first by type and then by position
                        items.sort { $0.type != $1.type ? $0.type < $1.type : $0.position < $1.position }
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
        let type: Int
        let position: Int
    }
}

struct DMa: View {
    @ObservedObject var webSocketClient: WebSocketClient
    let token: String
    let username: String
    @State private var items: [Item1] = []

    var body: some View {
        VStack {
            List(items) { item in
                if !item.name.starts(with: "@ ") {
                    Text(item.name)
                } else {
                    NavigationLink {
                        ChannelView(channelid: item.id, webSocketClient: webSocketClient, token: token, guild: "", channelname: item.name, username: username)
                    } label: {
                        Text(item.name)
                    }
                }
            }
        }
        .onAppear() {
            webSocketClient.getcurrentchannel(input: "", guild: "")
            webSocketClient.data = []
            webSocketClient.messageIDs = []
            webSocketClient.icons = []
            webSocketClient.icons = []
            webSocketClient.usernames = []
            webSocketClient.disconnect()
            getDiscordDMs(token: token) { items in
                self.items = items
            }
        }
    }
    func getDiscordDMs(token: String, completion: @escaping ([Item1]) -> Void) {
        guard let url = URL(string: "https://discord.com/api/v9/users/@me/channels") else {
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

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
            } else if let data = data {
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        var items: [Item1] = []
                        for dict in jsonArray {
                            if let id = dict["id"] as? String, let type = dict["type"] as? Int {
                                if type == 1, let recipients = dict["recipients"] as? [[String: Any]], let global_name = recipients.first?["global_name"] as? String, let username = recipients.first?["username"] as? String {
                                    var name = ""
                                    if global_name.isEmpty {
                                        name = "@ \(username)"
                                    } else {
                                        name = "@ \(global_name)"
                                    }
                                    let lastMessageId = dict["last_message_id"] as? String
                                    let item = Item1(id: id, name: name, heading: nil, position: Int(lastMessageId ?? "") ?? 0)
                                    items.append(item)
                                } else if type == 3 {
                                    let name = "Group DM"
                                    let lastMessageId = dict["last_message_id"] as? String
                                    let item = Item1(id: id, name: name, heading: nil, position: Int(lastMessageId ?? "") ?? 0)
                                    items.append(item)
                                }
                            }
                        }
                        // Sort the items based on the last message ID
                        items.sort { $0.position > $1.position }
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

    struct Item1: Identifiable {
        let id: String
        let name: String
        let heading: String?
        let position: Int
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

func sendPostRequest1(content: String, token: String, channel: String, messageReference: [String: String]?) {
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
    var bodyObject: [String: Any] = ["content": content]
    if let messageReference = messageReference {
        bodyObject["message_reference"] = messageReference
    }
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


func getDiscordGuilds1(token: String, completion: @escaping ([(name: String, id: String, icon: String?)]) -> Void) {
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

struct Message: Identifiable {
    let id: String
    let content: String
    let username: String
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
    @State var currentsearch = ""
    let channelid: String
    @State var selectedMessage: Message? = nil
    @ObservedObject var webSocketClient: WebSocketClient
    let keychain = KeychainSwift()
    let token: String
    let guild: String
    let channelname: String
    let username: String
    @State private var translation = ""
    @State var replyMessage: Message? = nil
    
    @State var ispickedauto = false
    @State var showEmojiPicker = false {
        didSet {
            print("Emoji Picker State has changed to: \(showEmojiPicker)")
        }
    }
    @State var previousMessageDate: Date? = nil
    @State var emojis: [Emoji] = []

        var body: some View {
            VStack {
                ScrollView {
                    ForEach(webSocketClient.data, id: \.messageId) { messageData in
                        VStack {
                            let timestamp = (Int(messageData.messageId)! >> 22 + 1420070400000) / 1000
                            let messageDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                            
                            // Check if the message is the first message of a new day
                            if let previousDate = previousMessageDate, !Calendar.current.isDate(previousMessageDate!, inSameDayAs: messageDate) {
                                // If it is, add a section divider here
                                Divider()
                                    .padding(.vertical)
                                    .onAppear() {
                                        print(previousDate)
                                    }
                            }
                            
                            HStack {
                                AsyncImage(url: URL(string: messageData.icon)) { image in
                                    image.resizable()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                        .onAppear() {
                                            previousMessageDate = messageDate
                                        }
                                        .contextMenu {
                                            // Show the message date when holding the message
                                            Text("Message Date: \(messageDate)")
                                            Button(action: {
                                                self.selectedMessage = Message(id: messageData.messageId, content: messageData.message, username: messageData.username)
                                            }) {
                                                Text("Delete")
                                            }
                                            Button(action: {
                                                self.replyMessage = Message(id: messageData.messageId, content: messageData.message, username: messageData.username)
                                            }) {
                                                Text("Reply")
                                            }
                                        }
                                } placeholder: {
                                    ProgressView()
                                        .onAppear() {
                                            previousMessageDate = messageDate
                                        }
                                }
                                
                                MessageChannelView(token: token, message: messageData.message)
                                    .onAppear() {
                                        print(messageDate)
                                    }
                                if !messageData.attachment.isEmpty {
                                    MediaView(url: messageData.attachment)
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
                }
                if let replyMessage = replyMessage {
                    HStack {
                        Text("Replying to \(replyMessage.username):")
                            .font(.headline)
                        Text(replyMessage.content)
                            .font(.subheadline)
                        Spacer()
                        Button(action: {
                            self.replyMessage = nil
                        }) {
                            Image(systemName: "xmark.circle")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                }
                if showEmojiPicker {
                    EmojiPicker(text: $text, pickauto: $ispickedauto, currentsearch: $currentsearch, emojis: emojis)
                }
                HStack {
                    TextField("Message \(channelname)", text: $text)
                        .onChange(of: text) { newValue in
                            let patternDoubleColon = "^(.*\\S)?:(.*):\\s*(\\S*)$"
                            let patternSingleColon = "^(.*\\S)?:\\s*(\\S*)$"
                            let regexDoubleColon = try? NSRegularExpression(pattern: patternDoubleColon)
                            let regexSingleColon = try? NSRegularExpression(pattern: patternSingleColon)
                            
                            if let match = regexDoubleColon?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                                showEmojiPicker = false
                            } else if let match = regexSingleColon?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                                let range = Range(match.range(at: 2), in: text)!
                                let textAfterColon = String(text[range])
                                currentsearch = textAfterColon
                                showEmojiPicker = true
                                ispickedauto = false
                            } else {
                                showEmojiPicker = false
                                currentsearch = ""
                                ispickedauto = false
                            }
                        }
                        .onSubmit {
                            let patternDoubleColon = "^(.*\\S)?:(.*):\\s*(\\S*)$"
                            let regexDoubleColon = try? NSRegularExpression(pattern: patternDoubleColon)
                            
                            if let match = regexDoubleColon?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                                let range = Range(match.range(at: 2), in: text)!
                                let textBetweenColons = String(text[range])
                                currentsearch = textBetweenColons
                                ispickedauto = true
                                showEmojiPicker = false
                            }
                            
                            if let replyMessage = replyMessage {
                                sendPostRequest1(content: text, token: token, channel: channelid, messageReference: ["message_id": replyMessage.id])
                                self.replyMessage = nil
                            } else {
                                sendPostRequest1(content: text, token: token, channel: channelid, messageReference: nil)
                            }
                            text = ""
                            ispickedauto = false
                            if showEmojiPicker {
                                showEmojiPicker.toggle()
                            }
                        }

                        .onAppear() {
                            fetchEmojis(token: token, guildID: guild) { fetchedEmojis in
                                emojis = fetchedEmojis ?? []
                            }
                        }
                        
                        
                    Button("emoji") {
                        // keychain.set("", forKey: "token")
                        // hasbeenopened = true
                        if !emojis.isEmpty {
                            showEmojiPicker.toggle()
                        }
                    }
                }
            }
            .padding()
            .alert(item: $selectedMessage) { message in
                Alert(
                    title: Text("Delete Message"),
                    message: Text("Are you sure you want to delete this message?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteDiscordMessage(token: token, serverID: "", channelID: channelid, messageID: message.id)
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear() {
                fetchEmojis(token: token, guildID: guild) { fetchedEmojis in
                    if fetchedEmojis != nil {
                        emojis = fetchedEmojis!
                    }
                }
                webSocketClient.data = []
                webSocketClient.disconnect()
                getDiscordMessages(token: token, channelID: channelid, webSocketClient: webSocketClient)
                webSocketClient.getcurrentchannel(input: channelid, guild: guild)
                webSocketClient.getTokenAndConnect()
                
            }
        }
}

struct EmojiPicker: View {
    @Binding var text: String
    @Binding var pickauto: Bool
    @Binding var currentsearch: String
    var emojis: [Emoji] // Your Emoji model here

    var firstMatchingEmoji: Emoji? {
        emojis.first { emoji in
            currentsearch.isEmpty || emoji.name.lowercased().contains(currentsearch.lowercased())
        }
    }

    var body: some View {
        ScrollView {
            ForEach(emojis.filter { emoji in
                currentsearch.isEmpty || emoji.name.lowercased().contains(currentsearch.lowercased())
            }, id: \.id) { emoji in
                let imageUrl = "https://cdn.discordapp.com/emojis/\(emoji.id).png?size=96"
                Button {
                    text = text.replacingOccurrences(of: ":\(currentsearch)", with: "")
                    text += "<:\(emoji.name):\(emoji.id)>"
                } label: {
                    HStack {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image.resizable()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                        }
                        Text(emoji.name)
                    }
                }
                .onChange(of: pickauto, perform: { newValue in
                    if pickauto, let firstEmoji = firstMatchingEmoji, firstEmoji.id == emoji.id {
                        text = text.replacingOccurrences(of: ":\(currentsearch):", with: "")
                        text += "<:\(firstEmoji.name):\(firstEmoji.id)>"
                        pickauto = false
                    }
                })
            }
        }
    }
}


struct Emoji: Codable {
    let id: String
    let name: String
}

func fetchEmojis(token: String, guildID: String, completion: @escaping ([Emoji]?) -> Void) {
    let url = URL(string: "https://discord.com/api/guilds/\(guildID)/emojis")!
    var request = URLRequest(url: url)
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
        if let data = data {
            let decoder = JSONDecoder()
            if let emojis = try? decoder.decode([Emoji].self, from: data) {
                completion(emojis)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    task.resume()
}


struct MessageChannelView: View {
    let token: String
    let message: String
    var body: some View {
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
            Spacer()
        } else {
            // Process user IDs
            if let match = userIdMatch {
                if let userIdRange = Range(match.range(at: 1), in: message) {
                    let userId = String(message[userIdRange])
                    MessageView(message: message, isEmoji: "userid", token: token)
                    Spacer()
                }
            }
            
            // Process static emojis
            if let match = emojiMatch {
                if let emojiRange = Range(match.range(at: 2), in: message) {
                    let emojiId = String(message[emojiRange])
                    MessageView(message: message, isEmoji: "yes", token: token)
                    Spacer()
                }
            }
            
            // Process animated emojis
            if let match = animatedEmojiMatch {
                if let animatedEmojiRange = Range(match.range(at: 2), in: message) {
                    let animatedEmojiId = String(message[animatedEmojiRange])
                    MessageView(message: message, isEmoji: "no", token: token)
                    Spacer()
                }
            }
        }
    }
}




// https://discord.com/api/v9/channels/1119174763651272786/messages?limit=50


func getDiscordMessages(token: String, channelID: String, webSocketClient: WebSocketClient) {
    let url = URL(string: "https://discord.com/api/channels/\(channelID)/messages?limit=25")!
    
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
    
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data else {
            print("No data in response: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                var uniqueMessages = Set<String>()
                for message in json {
                    if let content = message["content"] as? String,
                       let id = message["id"] as? String,
                       let user = message["author"] as? [String: Any],
                       let username = user["username"] as? String,
                       let avatar = user["avatar"] as? String {
                        DispatchQueue.main.async {
                            let avatarURL = "https://cdn.discordapp.com/avatars/\(user["id"] ?? "")/\(avatar).png"
                            
                            // Handle attachments
                            var attachmentURL = ""
                            if let attachments = message["attachments"] as? [[String: Any]] {
                                for attachment in attachments {
                                    if let url = attachment["url"] as? String {
                                        attachmentURL = url
                                    }
                                }
                            }
                            
                            let messageData = MessageData(icon: avatarURL, message: content, attachment: attachmentURL, username: username, messageId: id)
                            webSocketClient.data.append(messageData)
                            uniqueMessages.insert(id)
                        }
                    }
                }
                // Sort the messages by their IDs (which are timestamps)
                
                DispatchQueue.main.async {
                    let sortedIndices = webSocketClient.data.indices.sorted { webSocketClient.data[$0].messageId < webSocketClient.data[$1].messageId }
                    webSocketClient.data = sortedIndices.map { webSocketClient.data[$0] }
                }
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }
    
    task.resume()
}



func deleteDiscordMessage(token: String, serverID: String, channelID: String, messageID: String) {
    let url = URL(string: "https://discord.com/api/channels/\(channelID)/messages/\(messageID)")!
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
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

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            print(error?.localizedDescription ?? "No data")
            return
        }
        let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
        if let responseJSON = responseJSON as? [String: Any] {
            print(responseJSON)
        }
    }

    task.resume()
}
