//
//  ChannelView.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI
import KeychainSwift

struct ChannelView: View {
    // MARK: - Properties
    @StateObject var webSocketService: WebSocketService
    @ObservedObject private var keyboard = KeyboardResponder()
    @State private var message: String = ""
    @State var currentchannelname: String
    @State private var showingUploadPicker = false
    @State private var showingFilePicker = false
    @State private var showUserProfile = false
    @State var fileURL: URL?
    @State var repliedMessage: Message?
    @State var currentid: String
    @State var currentGuild: Guild?
    @State var scrollToId: String? = nil
    @State var editMessage: Message?
    @State var typingWorkItem: DispatchWorkItem?
    @State private var shown = true
    @StateObject private var tabBarModifier = TabBarModifier.shared
    
    private let keychain = KeychainSwift()
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            // Messages area
            messagesScrollView
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        // Reply/edit indicator
                        if let replyMessage = repliedMessage {
                            replyingToView(replyMessage: replyMessage)
                        } else if let editingMessage = editMessage {
                            editingMessageView(editingMessage: editingMessage)
                        }
                        
                        // File preview
                        if let fileURL = fileURL {
                            filePreviewView(fileURL: fileURL)
                        }
                        
                        // File picker
                        if showingUploadPicker {
                            filePickerView
                        }
                        
                        // Message input
                        messageInputView
                            .padding(.horizontal)
                            // .padding(.bottom, tabBarModifier.shown ?
                                   //  keyboard.currentHeight :
                                   //  keyboard.currentHeight - tabBarModifier.tabBarSize)
                            .animation(.easeOut(duration: 0.16), value: keyboard.currentHeight)
                            .background(
                                Rectangle()
                                    .fill(.thinMaterial)
                            )
                    }
                }
        }
        .ignoresSafeArea(.container)
        .sheet(isPresented: $showUserProfile) {
            userProfileView
                .presentationDetents([.medium, .large])
        }
        #if os(macOS)
        .detectTabChanges { isActive in
            handleTabChange(isActive: isActive)
        }
        .frame(maxWidth: NSScreen.main?.frame.width)
        #elseif os(iOS)
        .frame(maxWidth: UIScreen.main.bounds.width)
        #endif
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.video, .audio, .image, .item],
            onCompletion: handleFileImport
        )
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
    }
    
    // MARK: - View Components
    private var messagesScrollView: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(webSocketService.data.filter { $0.channelId == currentid }, id: \.messageId) { messageData in
                        if webSocketService.currentUser.id == messageData.author.authorId {
                            selfMessageView(messageData: messageData)
                                .id(messageData.messageId)
                                .transition(.opacity)
                        } else {
                            otherMessageView(messageData: messageData)
                                .id(messageData.messageId)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .onChange(of: scrollToId) { newValue in
                if let scrollToId,
                   let targetMessage = webSocketService.data.first(where: { $0.messageId == scrollToId }) {
                    withAnimation {
                        scrollViewProxy.scrollTo(targetMessage.messageId, anchor: .center)
                        self.scrollToId = nil
                    }
                }
            }
            .scrollAnchorBottom(websocket: webSocketService, scrollproxy: scrollViewProxy)
        }
    }
    
    private func selfMessageView(messageData: Message) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            MessageView(messageData: messageData, reply: $scrollToId, webSocketService: webSocketService, isCurrentUser: true)
                .contextMenu {
                    Button(action: { showUserProfile = true }) {
                        Label("Show User", systemImage: "person")
                    }
                    
                    Button(action: {
                        editMessage = messageData
                        message = messageData.content
                    }) {
                        Label("Edit Message", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { deleteMessage(message: messageData) }) {
                        Label("Delete Message", systemImage: "trash")
                    }
                    
                    Button(action: { repliedMessage = messageData }) {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                }
        }
    }
    
    private func otherMessageView(messageData: Message) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MessageView(messageData: messageData, reply: $scrollToId, webSocketService: webSocketService, isCurrentUser: false)
                .contextMenu {
                    Button(action: { repliedMessage = messageData }) {
                        Label("Reply", systemImage: "arrowshape.turn.up.right")
                    }
                }
        }
    }
    
    private func filePreviewView(fileURL: URL) -> some View {
        VStack(alignment: .trailing) {
            Button {
                self.fileURL = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.trailing, 8)
            
            MediaPreview(file: fileURL)
                .frame(maxHeight: 200)
                .cornerRadius(8)
                .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.8))
    }
    
    private func replyingToView(replyMessage: Message) -> some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replying to \(replyMessage.author.globalName ?? replyMessage.author.username)")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(replyMessage.content)
                            .font(.footnote)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { self.repliedMessage = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.8))
        }
    }
    
    private func editingMessageView(editingMessage: Message) -> some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Editing message")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(editingMessage.content)
                            .font(.footnote)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    message = ""
                    self.editMessage = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.8))
        }
    }
    
    private var filePickerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                PhotoPickerView() { savedImageURL in
                    fileURL = savedImageURL
                }
                
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Select File", systemImage: "paperclip")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: { showingUploadPicker = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.8))
        }
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            // Add attachment button
            Button(action: { showingUploadPicker = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }
            
            // Message text field
            TextField(
                (editMessage == nil) ? "Message \(currentchannelname)" : "Editing message...",
                text: $message
            )
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
            .onChange(of: message) { _ in
                handleTypingIndicator()
            }
            .onSubmit {
                handleMessageSubmit()
            }
            
            // Send button
            Button(action: handleMessageSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(message.isEmpty && fileURL == nil ? .gray : .blue)
            }
            .disabled(message.isEmpty && fileURL == nil)
        }
        .padding(.vertical, 10)
    }
    
    private var userProfileView: some View {
        VStack(spacing: 20) {
            // User avatar and name
            VStack(spacing: 12) {
                if let avatar = webSocketService.currentUser.avatar {
                    AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(webSocketService.currentUser.id)/\(avatar).png")) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 3)
                            )
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 90, height: 90)
                            .overlay(
                                ProgressView()
                            )
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Text(String(webSocketService.currentUser.username.prefix(1)))
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.blue)
                        )
                }
                
                VStack(spacing: 4) {
                    Text(webSocketService.currentUser.global_name ?? webSocketService.currentUser.username)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if webSocketService.currentUser.global_name != nil {
                        Text(webSocketService.currentUser.username)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top)
            
            // Divider with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .gray.opacity(0.3), .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal)
            
            // User bio
            if let bio = webSocketService.currentUser.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Me")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(LocalizedStringKey(bio))
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Methods
    private func handleMessageSubmit() {
        guard !message.isEmpty || fileURL != nil else { return }
        
        let token = keychain.get("token") ?? ""
        let channel = webSocketService.currentchannel
        
        if let repliedMessage = repliedMessage {
            SendMessage(
                content: message,
                fileUrl: fileURL,
                token: token,
                channel: channel,
                messageReference: ["message_id": repliedMessage.messageId]
            )
        } else if let editMessages = editMessage {
            var editedMessage = editMessages
            editedMessage.content = message
            Stossycord.editMessage(message: editedMessage)
        } else {
            SendMessage(
                content: message,
                fileUrl: fileURL,
                token: token,
                channel: channel,
                messageReference: nil
            )
        }
        
        // Clear variables after sending
        message = ""
        repliedMessage = nil
        editMessage = nil
        fileURL = nil
        showingFilePicker = false
        
        clearTemporaryFolder()
    }
    
    private func handleOnAppear() {
        guard let token = keychain.get("token") else { return }
        TabBarModifier.shared.hideTabBar()
        
        DispatchQueue.main.async {
            webSocketService.currentchannel = currentid
            getDiscordMessages(token: token, webSocketService: webSocketService)
        }
    }
    
    private func handleOnDisappear() {
        webSocketService.currentchannel = ""
        webSocketService.data.removeAll(where: { $0.channelId == currentid })
        TabBarModifier.shared.showTabBar()
        
        if currentchannelname.starts(with: "@") {
            guard let token = keychain.get("token") else { return }
            getDiscordDMs(token: token) { items in
                webSocketService.dms = items
            }
        }
    }
    
    private func handleTypingIndicator() {
        if message.count > 3 {
            typingWorkItem?.cancel()
            
            typingWorkItem = DispatchWorkItem {
                sendtyping(token: webSocketService.token, channel: currentid)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: typingWorkItem!)
        }
    }
    
    private func handleTabChange(isActive: Bool) {
        if isActive {
            guard let token = keychain.get("token") else { return }
            webSocketService.currentchannel = currentid
            getDiscordMessages(token: token, webSocketService: webSocketService)
            
            if let currentGuild = currentGuild {
                getGuildRoles(guild: currentGuild) { guilds in
                    self.webSocketService.currentroles = guilds
                }
            }
        } else {
            webSocketService.currentchannel = ""
            webSocketService.currentroles.removeAll()
        }
    }
    
    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let start = url.startAccessingSecurityScopedResource()
            
            defer {
                if start {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let fileManager = FileManager.default
            let targetURL = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent(url.lastPathComponent)
            
            do {
                try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(),
                                              withIntermediateDirectories: true,
                                              attributes: nil)
                try fileManager.copyItem(at: url, to: targetURL)
                self.fileURL = targetURL
            } catch {
                print("Failed to save file: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            print("File import error: \(error.localizedDescription)")
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

// MARK: - Scroll Modifier
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
                        scrollViewProxy.scrollTo(lastMessage.messageId, anchor: .bottom)
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

// MARK: - macOS Tab Observer
#if os(macOS)
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

// MARK: - Keyboard Responder
final class KeyboardResponder: ObservableObject {
    private var notificationCenter: NotificationCenter
    @Published private(set) var currentHeight: CGFloat = 0

    init(center: NotificationCenter = .default) {
        notificationCenter = center
        notificationCenter.addObserver(self, selector: #selector(keyBoardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyBoardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    @objc func keyBoardWillShow(notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            currentHeight = keyboardSize.height
        }
    }

    @objc func keyBoardWillHide(notification: Notification) {
        currentHeight = 0
    }
}
