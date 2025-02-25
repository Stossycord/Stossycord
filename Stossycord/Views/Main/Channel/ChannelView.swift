//
//  ChannelView.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI
import KeychainSwift

struct ChannelView: View {
    @StateObject var webSocketService: WebSocketService
    @State var message: String = ""
    @State var currentchannelname: String
    @State var uploadfiles = false
    @State var showcurrentuser = false
    @State var fileURL: URL?
    @State var repliedmessage: Message?
    @State var currentid: String
    @State var currentGuild: Guild?
    let keychain = KeychainSwift()
    @State private var showTranslation = false
    @State var scrollto: String = ""
    @State var showingFilePicker = false
    @State private var typingWorkItem: DispatchWorkItem?
    @State var shown = true
    @State var editMessage: Message?
    
    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    ForEach(webSocketService.data.filter { $0.channelId == currentid }, id: \.messageId) { messageData in
                        
                        VStack {
                            if webSocketService.currentUser.id == messageData.author.authorId {
                                VStack {
                                    HStack {
                                        MessageSelfView(messageData: messageData, reply: $scrollto, webSocketService: webSocketService)
                                            .contextMenu {
                                                Button {
                                                    showcurrentuser = true
                                                } label: {
                                                    Text("Show User")
                                                }
                                                
                                                
                                                Button {
                                                    editMessage = messageData
                                                    
                                                    message = messageData.content
                                                } label: {
                                                    Text("Edit Message")
                                                }
                                                
                                                Button {
                                                    repliedmessage = messageData
                                                } label: {
                                                    Text("Reply")
                                                }
                                            }
                                    }
                                    
                                    if let messageattachments = messageData.attachments {
                                        HStack {
                                            Spacer()
                                            ForEach(messageattachments, id: \.id) { attachment in
                                                MediaView(url: attachment.url)
                                            }
                                        }
                                    }
                                }
                            } else {
                                VStack {
                                    HStack {
                                        MessageView(messageData: messageData, reply: $scrollto, webSocketService: webSocketService)
                                            .contextMenu {
                                                Button {
                                                    repliedmessage = messageData
                                                } label: {
                                                    Text("Reply")
                                                }
                                            }
                                    }
                                    
                                    if let messageattachments = messageData.attachments {
                                        HStack {
                                            ForEach(messageattachments, id: \.id) { attachment in
                                                MediaView(url: attachment.url)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        .id(messageData.messageId)  // Set an ID for each message
                    }
                }
                .onChange(of: scrollto) { newValue in
                    if scrollto.isEmpty { return }
                    if let lastMessage = webSocketService.data.first(where: { $0.messageId == scrollto }) {
                        withAnimation {
                            scrollViewProxy.scrollTo(lastMessage.messageId, anchor: .center)
                            scrollto = ""
                        }
                    }
                }
                .scrollAnchorBottom(websocket: webSocketService, scrollproxy: scrollViewProxy)
            }
            
            if let fileURL = fileURL {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            self.fileURL = nil
                        } label: {
                            Image(systemName: "x.circle")
                        }
                    }
                    MediaPreview(file: fileURL)
                        
                }
            }
            
            if let replyMessage = repliedmessage {
                HStack {
                    Text("Replying to \(replyMessage.author.globalName ?? replyMessage.author.username):")
                        .font(.headline)
                    Text(replyMessage.content)
                        .font(.subheadline)
                    Spacer()
                    Button(action: {
                        self.repliedmessage = nil
                    }) {
                        Image(systemName: "xmark.circle")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
            } else if let replyMessage = editMessage {
                HStack {
                    Text("Editing: \(replyMessage.author.globalName ?? replyMessage.author.username):")
                        .font(.headline)
                    Text(replyMessage.content)
                        .font(.subheadline)
                    Spacer()
                    Button(action: {
                        message = ""
                        self.editMessage = nil
                    }) {
                        Image(systemName: "xmark.circle")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
            }
            
            if showingFilePicker {
                HStack(alignment: .center) {
                    PhotoPickerView() { savedImageURL in
                        fileURL = savedImageURL
                    }
                    Button {
                        uploadfiles = true
                    } label: {
                        Text("Select File")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    Button(action: {
                        showingFilePicker = false
                    }) {
                        Image(systemName: "xmark.circle")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
            }
            
            HStack {
                TextField("\((editMessage == nil) ? "Message" : "Editing Message in ") \(currentchannelname)", text: $message)
                    .padding()
                    .textFieldStyle(.plain)

                #if !os(macOS)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.systemGray5))
                    )
                #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .onSubmit(handleMessageSubmit)
                    .onAppear(perform: handleOnAppear)
                    .onDisappear(perform: handleOnDisappear)
                    .onChange(of: message) { newValue in
                        if message.count > 3 {
                            typingWorkItem?.cancel()

                            typingWorkItem = DispatchWorkItem {
                                sendtyping(token: webSocketService.token, channel: currentid)
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: typingWorkItem!)
                        }
                    }
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(10)
                        .background(Circle().fill(Color.blue.opacity(0.2)))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 5)
                .buttonStyle(.plain)
            }
            .popover(isPresented: $showcurrentuser, content: {
                VStack {
                    HStack {
                        if let avatar = webSocketService.currentUser.avatar {
                            AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(webSocketService.currentUser.id)/\(avatar).png")) { image in
                                image.resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } placeholder: {
                                ProgressView()
                            }
                        } else {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                        
                        Text(webSocketService.currentUser.global_name ?? webSocketService.currentUser.username)
                            .font(.headline)
                            .bold()
                    }
                    if webSocketService.currentUser.global_name != nil {
                        Text(webSocketService.currentUser.username)
                            .font(.caption)
                    }
                    if let bio = webSocketService.currentUser.bio {
                        Text(LocalizedStringKey(bio))
                            .multilineTextAlignment(.leading)
                        // .font(.system(size: 18))
                            .padding(.horizontal)
                    }
                    
                }
                
            })
            #if os(macOS)
            .detectTabChanges { isActive in
                print("Tab is now \(isActive ? "active" : "inactive")")
                
                
                if isActive {
                    guard let token = keychain.get("token") else { return }
                    webSocketService.currentchannel = currentid
                    
                    
                    getDiscordMessages(token: token, webSocketService: webSocketService)
                    
                    
                    if let currentGuild {
                        getGuildRoles(guild: currentGuild) { guilds in
                            self.webSocketService.currentroles = guilds
                            
                        }
                    }
                } else {
                    webSocketService.currentchannel = ""
                    // webSocketService.data.removeAll(where: { $0.channelId == currentid })
                    webSocketService.currentroles.removeAll()
                }
            }
            #endif
#if os(macOS)
            .frame(maxWidth: NSScreen.main?.frame.width)
#elseif os(iOS)
            .frame(maxWidth: UIScreen.main.bounds.width)
#endif
            .padding()
            .fileImporter(isPresented: $uploadfiles, allowedContentTypes: [.video, .audio, .image, .item]) { result in
                switch result {
                case .success(let url):
                    let start = url.startAccessingSecurityScopedResource()
                    
                    defer {
                        if start {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    let fileManager = FileManager.default
                    let targetURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent(url.lastPathComponent)
                    
                    do {
                        try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try fileManager.copyItem(at: url, to: targetURL)
                        self.fileURL = targetURL
                    } catch {
                        print("Failed to save file: \(error.localizedDescription)")
                    }
                    
                case .failure(let error):
                    print("wow error: \(error.localizedDescription)")
                }
            }
            
        }
        #if os(macOS)
        .frame(maxWidth: NSScreen.main?.frame.width, maxHeight: NSScreen.main?.frame.height)
        #elseif os(iOS)
        .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height)
        #endif

    }
    
    private func handleMessageSubmit() {
        print("message: \(message)")
        
        let token = keychain.get("token") ?? ""
        let channel = webSocketService.currentchannel
        
        if let repliedMessage = repliedmessage {
            SendMessage(content: message, fileUrl: fileURL, token: token, channel: channel, messageReference: ["message_id": repliedMessage.messageId])
        } else if let editMessages = editMessage {
            var editedMessage = editMessages
            
            editedMessage.content = message
            Stossycord.editMessage(message: editedMessage)
        } else {
            SendMessage(content: message, fileUrl: fileURL, token: token, channel: channel, messageReference: nil)
        }
        
        // Clear variables after sending
        message = ""
        repliedmessage = nil
        editMessage = nil
        fileURL = nil
        
        showingFilePicker = false
        
        clearTemporaryFolder()
    }
    
    
    

    private func handleOnAppear() {
        guard let token = keychain.get("token") else { return }
        print("test appear")
        DispatchQueue.main.async {
            webSocketService.currentchannel = currentid
            getDiscordMessages(token: token, webSocketService: webSocketService)
        }
    }

    private func handleOnDisappear() {
        webSocketService.currentchannel = ""
        webSocketService.data.removeAll(where: { $0.channelId == currentid })
        print("test dissapear")
        if currentchannelname.starts(with: "@") {
            guard let token = keychain.get("token") else { return }
            getDiscordDMs(token: token) { items in
                webSocketService.dms = items
            }
        }
    }

    private func clearTemporaryFolder() {
        let fileManager = FileManager.default
        let tempDirectory = FileManager.default.temporaryDirectory.path
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDirectory)
            for file in tempFiles {
                let filePath = (tempDirectory as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: filePath)
            }
            print("Temporary folder cleared.")
        } catch {
            print("Error clearing temporary folder: \(error.localizedDescription)")
        }
    }
}


struct ScrollLock: ViewModifier {
    var webSocketService: WebSocketService
    var scrollViewProxy: ScrollViewProxy

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .defaultScrollAnchor(.bottom)
        } else {
            content
                .onChange(of: webSocketService.data.count) { _ in
                    if let lastMessage = webSocketService.data.last {
                        // withAnimation {
                            scrollViewProxy.scrollTo(lastMessage.messageId, anchor: .bottom)
                        // }
                    }
                }
        }
    }
}

extension View {
    func scrollAnchorBottom(websocket: WebSocketService, scrollproxy: ScrollViewProxy) -> some View {
        self.modifier(ScrollLock(webSocketService: websocket, scrollViewProxy: scrollproxy))
    }
}

#if os(macOS)
import AppKit
import AppKit

struct WindowTabObserver: ViewModifier {
    @State private var isActiveTab = true
    @State private var currentWindow: NSWindow?
    let onTabChange: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async {
                    currentWindow = NSApplication.shared.keyWindow
                }
                setupNotifications()
            }
            .onDisappear {
                removeNotifications()
            }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            
            // Only trigger if it's the same window
            if window == currentWindow {
                isActiveTab = true
                onTabChange(true)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            
            // Only trigger if it's the same window
            if window == currentWindow {
                isActiveTab = false
                onTabChange(false)
            }
        }
        
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResignMainNotification,
            object: nil
        )
    }
}

extension View {
    func detectTabChanges(onChange: @escaping (Bool) -> Void) -> some View {
        modifier(WindowTabObserver(onTabChange: onChange))
    }
}
#endif
