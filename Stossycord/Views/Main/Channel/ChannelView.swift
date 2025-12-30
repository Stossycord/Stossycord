//
//  ChannelView.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI
import KeychainSwift
import PhotosUI

struct ScrollMarker: UIViewRepresentable {
    let id: String
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.accessibilityIdentifier = id
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ChannelView: View {
    // MARK: - Properties
    @StateObject var webSocketService: WebSocketService
    @ObservedObject private var keyboard = KeyboardResponder()
    @State private var message: String = ""
    @State var currentchannelname: String
    @State private var showingUploadPicker = false
    @State private var showingFilePicker = false
    @State var selectedAuthor: Author?
    @State var selectedUserProfile: UserProfile?
    @State private var isLoadingProfile = false
    @State var fileURL: URL?
    @State var repliedMessage: Message?
    @State var currentid: String
    @State var currentGuild: Guild?
    @State var scrollToId: String? = nil
    @State var editMessage: Message?
    @State var typingWorkItem: DispatchWorkItem?
    @State private var shown = true
    @StateObject private var tabBarModifier = TabBarModifier.shared
    @State private var showTokenWarning = false
    @State private var permissionStatus = ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
    @AppStorage("useNativePicker") private var useNativePicker: Bool = false
    @AppStorage("useRedesignedMessages") private var useRedesignedMessages: Bool = false
    @State private var showNativePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNativePhotoPicker = false
    @State private var finished = false
    
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
                        
                        // File preview - only show if user can attach files and send messages
                        if let fileURL = fileURL, permissionStatus.canAttachFiles && permissionStatus.canSendMessages {
                            filePreviewView(fileURL: fileURL)
                        }
                        
                        // File picker - only show if user can attach files and send messages
                        if showingUploadPicker && permissionStatus.canAttachFiles && permissionStatus.canSendMessages {
                            filePickerView
                        }
                        
                        // Message input
                        MessageBarView(
                            permissionStatus: permissionStatus,
                            placeholder: getPlaceholderText(),
                            canSendCurrentMessage: canSendCurrentMessage,
                            useNativePicker: useNativePicker,
                            message: $message,
                            showNativePicker: $showNativePicker,
                            showNativePhotoPicker: $showNativePhotoPicker,
                            showingFilePicker: $showingFilePicker,
                            showingUploadPicker: $showingUploadPicker,
                            onMessageChange: { _ in handleTypingIndicator() },
                            onSubmit: handleMessageSubmit
                        )
                            .padding(.horizontal)
                            // .padding(.bottom, tabBarModifier.shown ?
                                   //  keyboard.currentHeight :
                                   //  keyboard.currentHeight - tabBarModifier.tabBarSize)
                            .animation(.easeOut(duration: 0.16), value: keyboard.currentHeight)
                    }
                }
        }
        .ignoresSafeArea(.container)
        .sheet(item: $selectedAuthor, onDismiss: {
            selectedAuthor = nil
            selectedUserProfile = nil
            isLoadingProfile = false
        }) { author in
            UserProfileView(
                profile: selectedUserProfile,
                author: author,
                isLoading: isLoadingProfile,
                currentUserId: webSocketService.currentUser.id
            )
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
        .photosPicker(
            isPresented: $showNativePhotoPicker,
            selection: $selectedPhotoItem,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPhotoItem) { item in
            handlePhotoSelection(item)
        }
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
        .onChange(of: webSocketService.currentroles) { _ in
            updatePermissions()
        }
        .onChange(of: webSocketService.currentMembers) { _ in
            updatePermissions()
        }
        .alert("You're sharing your token", isPresented: $showTokenWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Send Anyway", role: .destructive) {
                sendMessage()
            }
        } message: {
            Text("Your message contains your Discord token. Sharing it with other people could open your account to other people. Do you want to send it?")
        }
    }
    
    // MARK: - View Components
    private var messagesScrollView: some View {
        UIKitScrollView(anchorTo: .bottom) { scrollProxy in
            
            LazyVStack {
                ForEach(webSocketService.data.filter { $0.channelId == currentid }, id: \.messageId) { messageData in
                    messageRow(for: messageData)
                        .id(messageData.messageId)
                        .background(ScrollMarker(id: messageData.messageId))
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .onChange(of: scrollToId) { newValue in
                if let scrollToId,
                   let targetMessage = webSocketService.data.first(where: { $0.messageId == scrollToId }) {
                    print("cool")
                    scrollProxy(targetMessage.messageId)
                    self.scrollToId = nil
                }
            }
            .onChange(of: webSocketService.data) { newval in
                if let scrollToId = newval.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollProxy(scrollToId.messageId)
                    }
                }
            }
            .onChange(of: finished) { newValue in
                if newValue, let id = webSocketService.data.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        scrollProxy(id.messageId)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func messageRow(for messageData: Message) -> some View {
        if webSocketService.currentUser.id == messageData.author.authorId {
            selfMessageView(messageData: messageData)
        } else {
            otherMessageView(messageData: messageData)
        }
    }

    
    private func selfMessageView(messageData: Message) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Group {
                if useRedesignedMessages {
                    let messages = webSocketService.data.filter { $0.channelId == currentid }
                    let currentIndex = messages.firstIndex { $0.messageId == messageData.messageId } ?? 0
                    let previousMessage = currentIndex > 0 ? messages[currentIndex - 1] : nil
                    let isGrouped = MessageViewRE.shouldGroupMessage(current: messageData, previous: previousMessage)
                    
                    MessageViewRE(
                        messageData: messageData, 
                        reply: $scrollToId, 
                        webSocketService: webSocketService, 
                        isCurrentUser: true, 
                        onProfileTap: { presentUserProfile(for: messageData.author) }, 
                        isGrouped: isGrouped, 
                        allMessages: messages
                    )
                } else {
                    MessageView(messageData: messageData, reply: $scrollToId, webSocketService: webSocketService, isCurrentUser: true, onProfileTap: { presentUserProfile(for: messageData.author) })
                }
            }
            .contextMenu {
                    Button(action: { 
                        presentUserProfile(for: messageData.author)
                    }) {
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
            Group {
                if useRedesignedMessages {
                    let messages = webSocketService.data.filter { $0.channelId == currentid }
                    let currentIndex = messages.firstIndex { $0.messageId == messageData.messageId } ?? 0
                    let previousMessage = currentIndex > 0 ? messages[currentIndex - 1] : nil
                    let isGrouped = MessageViewRE.shouldGroupMessage(current: messageData, previous: previousMessage)
                    
                    MessageViewRE(
                        messageData: messageData, 
                        reply: $scrollToId, 
                        webSocketService: webSocketService, 
                        isCurrentUser: false, 
                        onProfileTap: { presentUserProfile(for: messageData.author) }, 
                        isGrouped: isGrouped, 
                        allMessages: messages
                    )
                } else {
                    MessageView(messageData: messageData, reply: $scrollToId, webSocketService: webSocketService, isCurrentUser: false, onProfileTap: { presentUserProfile(for: messageData.author) })
                }
            }
            .contextMenu {
                    Button(action: { 
                        presentUserProfile(for: messageData.author)
                    }) {
                        Label("Show User", systemImage: "person")
                    }
                    
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
                if !useNativePicker {
                    PhotoPickerView() { savedImageURL in
                        if permissionStatus.canAttachFiles {
                            fileURL = savedImageURL
                        }
                    }
                    .disabled(!permissionStatus.canAttachFiles)
                    
                    Button {
                        if permissionStatus.canAttachFiles {
                            showingFilePicker = true
                        }
                    } label: {
                        Label("Files", systemImage: "paperclip")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(permissionStatus.canAttachFiles ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .foregroundColor(permissionStatus.canAttachFiles ? .blue : .gray)
                            .cornerRadius(8)
                    }
                    .disabled(!permissionStatus.canAttachFiles)
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
    
    private var canSendCurrentMessage: Bool {
        return permissionStatus.canSendMessages && (!message.isEmpty || (fileURL != nil && permissionStatus.canAttachFiles))
    }
    
    private func getPlaceholderText() -> String {
        if !permissionStatus.canSendMessages {
            return "You do not have permission to send messages"
        } else if editMessage != nil {
            return "Editing message..."
        } else {
            return "Message \(currentchannelname)"
        }
    }
    
    // MARK: - Methods
    private func handleMessageSubmit() {
        guard !message.isEmpty || fileURL != nil else { return }
        
        let token = keychain.get("token") ?? ""
        
        if message.contains(token) && !token.isEmpty {
            showTokenWarning = true
            return
        }
        
        sendMessage()
    }
    
    private func sendMessage() {
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
        
        Task { @MainActor in 
            webSocketService.currentchannel = currentid
            getDiscordMessages(token: token, webSocketService: webSocketService) {
                finished = true
            }
            
            if !currentchannelname.starts(with: "@") && webSocketService.currentMembers.isEmpty {
                let guildId = currentGuild?.id ?? webSocketService.currentguild.id
                if !guildId.isEmpty {
                    webSocketService.requestGuildMembers(guildID: guildId)
                }
            }
            
            updatePermissions()
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
            finished = false
            guard let token = keychain.get("token") else { return }
            webSocketService.currentchannel = currentid
            getDiscordMessages(token: token, webSocketService: webSocketService) { 
                finished = true
            }
            
            if let currentGuild = currentGuild {
                getGuildRoles(guild: currentGuild) { guilds in
                    self.webSocketService.currentroles = guilds
                    self.updatePermissions()
                }
            }
            updatePermissions()
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
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Save to temporary directory
                let fileName = item.itemIdentifier ?? UUID().uuidString
                let fileExtension = getFileExtension(for: item)
                let fullFileName = "\(fileName).\(fileExtension)"
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent(fullFileName)
                
                do {
                    try FileManager.default.createDirectory(
                        at: tempURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    try data.write(to: tempURL)
                    
                    Task { @MainActor in 
                        self.fileURL = tempURL
                        self.showingUploadPicker = false
                    }
                } catch {
                    print("Failed to save photo: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getFileExtension(for item: PhotosPickerItem) -> String {
        if let contentType = item.supportedContentTypes.first {
            if contentType.conforms(to: .image) {
                return "jpg"
            } else if contentType.conforms(to: .movie) {
                return "mp4"
            }
        }
        return "jpg"
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
    
    private func presentUserProfile(for author: Author) {
        if !Thread.isMainThread {
            Task { @MainActor in 
                self.presentUserProfile(for: author)
            }
            return
        }
        
        if let cachedProfile = CacheService.shared.getCachedUserProfile(userId: author.authorId) {
            selectedUserProfile = cachedProfile
            isLoadingProfile = false
        } else {
            selectedUserProfile = nil
            isLoadingProfile = true
        }
        
        selectedAuthor = author
        fetchUserProfile(userId: author.authorId, useCache: false)
    }
    
    private func fetchUserProfile(userId: String, useCache: Bool = true) {
        if useCache, let cachedProfile = CacheService.shared.getCachedUserProfile(userId: userId) {
            Task { @MainActor in 
                self.selectedUserProfile = cachedProfile
                self.isLoadingProfile = false
            }
            return
        }
        
        guard let token = keychain.get("token") else {
            Task { @MainActor in 
                self.isLoadingProfile = false
            }
            return
        }
        
        Task { @MainActor in 
            if self.selectedUserProfile == nil {
                self.isLoadingProfile = true
            }
        }
        
        getUserProfile(token: token, userId: userId) { profile in
            if let profile = profile {
                CacheService.shared.setCachedUserProfile(profile, userId: userId)
                Task { @MainActor in 
                    self.selectedUserProfile = profile
                    self.isLoadingProfile = false
                }
            } else {
                getBasicUserInfo(token: token, userId: userId) { basicUser in
                    Task { @MainActor in 
                        if let user = basicUser {
                            let fallbackProfile = UserProfile(
                                user: user,
                                connectedAccounts: nil,
                                premiumSince: nil,
                                premiumType: nil,
                                premiumGuildSince: nil,
                                profileThemesExperimentBucket: nil,
                                mutualGuilds: nil,
                                mutualFriends: nil,
                                userProfile: nil
                            )
                            self.selectedUserProfile = fallbackProfile
                        }
                        self.isLoadingProfile = false
                    }
                }
            }
        }
    }
    
    private func updatePermissions() {
        if currentchannelname.starts(with: "@") {
            permissionStatus = ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
            return
        }
        
        let currentUserId = webSocketService.currentUser.id
        let memberCount = webSocketService.currentMembers.count
        let roleCount = webSocketService.currentroles.count
        
        
        if webSocketService.currentUser.id.isEmpty {
            print("DEBUG: no user wtf, allowing all permissions?")
            permissionStatus = ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
            return
        }
        
        let currentChannel = webSocketService.channels
            .flatMap { $0.channels }
            .first { $0.id == currentid }
        
        let guildId = currentGuild?.id ?? webSocketService.currentguild.id
        
        permissionStatus = PermissionManager.getPermissionStatus(
            currentUser: webSocketService.currentUser,
            members: webSocketService.currentMembers,
            roles: webSocketService.currentroles,
            channel: currentChannel,
            guildId: guildId
        )
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
                Task { @MainActor in 
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
