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
    let keychain = KeychainSwift()
    @State private var showTranslation = false
    @State var scrollto: String = ""
    @State private var typingWorkItem: DispatchWorkItem?
    
    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    ForEach(webSocketService.data, id: \.messageId) { messageData in
                        
                        VStack {
                            if webSocketService.currentUser.id == messageData.author.authorId {
                                HStack {
                                    MessageSelfView(messageData: messageData, reply: $scrollto, webSocketService: webSocketService)
                                        .contextMenu {
                                            Button {
                                                showcurrentuser = true
                                            } label: {
                                                Text("Show User")
                                            }
                                            
                                            Button {
                                                repliedmessage = messageData
                                            } label: {
                                                Text("Reply")
                                            }
                                        }
                                }
                            } else {
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
                            }
                            
                            if let messageattachments = messageData.attachments {
                                ForEach(messageattachments, id: \.id) { attachment in
                                    MediaView(url: attachment.url)
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
                .onChange(of: webSocketService.data.count) { _ in
                    if let lastMessage = webSocketService.data.last {
                        withAnimation {
                            scrollViewProxy.scrollTo(lastMessage.messageId, anchor: .bottom)
                        }
                    }
                }
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
            }
            
            HStack {
                TextField("Message \(currentchannelname)", text: $message)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.systemGray5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .onSubmit(handleMessageSubmit)
                    .onAppear(perform: handleOnAppear)
                    .onDisappear(perform: handleOnDisappear)
                    .onChange(of: message) { newValue in
                        if message.count > 3 {
                            // Cancel any existing pending task
                            typingWorkItem?.cancel()

                            // Create a new debounced task
                            typingWorkItem = DispatchWorkItem {
                                sendtyping(token: webSocketService.token, channel: currentid)
                            }

                            // Execute the task after 1 second
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: typingWorkItem!)
                        }
                    }
                Button(action: { uploadfiles = true }) {
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(10)
                        .background(Circle().fill(Color.blue.opacity(0.2)))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 5)
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
    }
    
    private func handleMessageSubmit() {
        print("message: \(message)")
        
        let token = keychain.get("token") ?? ""
        let channel = webSocketService.currentchannel
        
        if let repliedMessage = repliedmessage {
            SendMessage(content: message, fileUrl: fileURL, token: token, channel: channel, messageReference: ["message_id": repliedMessage.messageId])
        } else {
            SendMessage(content: message, fileUrl: fileURL, token: token, channel: channel, messageReference: nil)
        }
        
        // Clear variables after sending
        message = ""
        repliedmessage = nil
        fileURL = nil
        
        clearTemporaryFolder()
    }

    private func handleOnAppear() {
        guard let token = keychain.get("token") else { return }
        webSocketService.currentchannel = currentid
        getDiscordMessages(token: token, webSocketService: webSocketService)
    }

    private func handleOnDisappear() {
        webSocketService.currentchannel = ""
        webSocketService.data.removeAll()
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

