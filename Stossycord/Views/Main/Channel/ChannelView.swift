//
//  ChannelView.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI
import KeychainSwift
import PhotosUI
import UniformTypeIdentifiers

#if canImport(AppKit)
struct ScrollMarker: NSViewRepresentable {
    let id: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.identifier = NSUserInterfaceItemIdentifier(id)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if nsView.identifier?.rawValue != id {
            nsView.identifier = NSUserInterfaceItemIdentifier(id)
        }
    }
}
#else
struct ScrollMarker: UIViewRepresentable {
    let id: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.accessibilityIdentifier = id
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif

struct ChannelView: View {
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
    @State var reactMessage: Message?
    @State var typingWorkItem: DispatchWorkItem?
    @State private var shown = true
    @StateObject private var tabBarModifier = TabBarModifier.shared
    @State private var showTokenWarning = false
    @State private var permissionStatus = ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
    @AppStorage("useNativePicker") private var useNativePicker: Bool = true
    @AppStorage("useRedesignedMessages") private var useRedesignedMessages: Bool = true
    @AppStorage("ignoreChatPermissions") private var ignoreChatPermissions: Bool = false
    @AppStorage(DesignSettingsKeys.allowFakeNitroEmojis) private var allowFakeNitroEmojis: Bool = true
    @State private var showNativePicker = false
    @State private var showEmojiPicker = false
    @State private var showReactionEmojiPicker = false
    @State private var showGIFPicker = false
    // @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNativePhotoPicker = false
    @State private var finished = false
    @ObservedObject private var user = CurrentUserService.shared
    @Environment(\.api) var discordAPI
    @State var scrollProxy: ScrollViewProxy!
    @State private var showMembers: Bool = false
    @State private var showAllMembers: Bool = false
    @State private var showMembersSheet: Bool = false
    @State private var lastTypingSent = Date.distantPast
    @State private var isLoadingOlderMessages = false
    @State private var canLoadOlderMessages = true
    @State private var oldestLoadedCursor: String?
    @State private var pendingScrollAnchor: UnitPoint?
    @State private var permissionUpdateWorkItem: DispatchWorkItem?
    
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = MessageBubbleStyle.imessage.rawValue
    @ObservedObject private var guildManager = CurrentGuildManager.shared
    
    var messageStyle: MessageBubbleStyle {
        .init(rawValue: messageStyleRawValue) ?? .imessage
    }
    
    private let keychain = KeychainSwift()
    
    var body: some View {
        GeometryReader { proxy in
            HStack {
                messagesScrollView
                    .padding(.horizontal, 8)
                    .animation(.none)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        composerArea
                    }
                
                membersView(proxy)
            }
        }
        .sheet(item: $selectedAuthor, onDismiss: {
            selectedAuthor = nil
            selectedUserProfile = nil
            isLoadingProfile = false
        }) { author in
            UserProfileView(
                profile: selectedUserProfile,
                author: author,
                isLoading: isLoadingProfile,
                currentUserId: user.user?.id ?? ""
            )
            .compatPresentationDetentsMediumLarge()
            .environmentObject(user)
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiView(guild: currentGuild) { emoji in
                insertEmoji(emoji)
            }
            .compatPresentationDetentsMedium()
            .compatPresentationDragIndicator()
            .environmentObject(user)
        }
#if os(macOS)
        .detectTabChanges { isActive in
            handleTabChange(isActive: isActive)
        }
        .frame(maxWidth: NSScreen.main?.frame.width)
#endif
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.video, .audio, .image, .item],
            onCompletion: handleFileImport
        )
        .channelSheets(
            showMembersSheet: $showMembersSheet,
            showAllMembers: $showAllMembers,
            showNativePhotoPicker: $showNativePhotoPicker,
            showGIFPicker: $showGIFPicker,
            reactMessage: $reactMessage,
            currentGuild: currentGuild,
            permissionStatus: permissionStatus,
            onRequestAllMembers: {
                if let guildId = currentGuild?.id {
                    webSocketService.requestGuildMembers(guildID: guildId, limit: 0)
                }
            },
            onPhotoSaved: { savedImageURL in
                if permissionStatus.canAttachFiles {
                    fileURL = savedImageURL
                    showingUploadPicker = false
                }
                showNativePhotoPicker = false
            },
            onPhotoCancel: {
                showNativePhotoPicker = false
            },
            onGIFSelected: { gif in
                sendGIF(gif)
            },
            onReactionSelected: { emoji, nativeEmoji, message in
                if let emoji {
                    addReaction(emoji, messageData: message)
                }
                
                if let nativeEmoji {
                    addReaction(.init(id: nil, name: nativeEmoji.emoji, animated: nil), messageData: message)
                }
            },
            membersSections: { guild in
                AnyView(membersSections(for: guild, showAll: false))
            },
            unhoistedMembersSection: { guild in
                AnyView(unhoistedMembersSection(for: guild))
            }
        )
        /*
         .onChange(of: selectedPhotoItem) { item in
         handlePhotoSelection(item)
         }*/
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
        .onChange(of: guildManager.roles) { _ in schedulePermissionsUpdate() }
        .onChange(of: guildManager.members) { _ in schedulePermissionsUpdate() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if user.guildManager.members[currentGuild?.id ?? ""]?.isEmpty == false {
                    Button {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            showMembers.toggle()
                        } else {
                            showMembersSheet.toggle()
                        }
                    } label: {
                        Label("Members", systemImage: "sidebar.trailing")
                    }
                }
            }
        }
        .alert(isPresented: $showTokenWarning) {
            Alert(
                title: Text("You're sharing your token"),
                message: Text("Your message contains your Discord token. Sharing it with other people could open your account to other people. Do you want to send it?"),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .destructive(Text("Send Anyway")) { sendMessage() }
            )
        }
    }
    
    // MARK: - Composer area (extracted to help the type-checker on iOS 15)
    
    @ViewBuilder
    private var composerArea: some View {
        VStack(spacing: 0) {
            typingIndicatorView
            
            if let replyMessage = repliedMessage {
                replyingToView(replyMessage: replyMessage)
            } else if let editingMessage = editMessage {
                editingMessageView(editingMessage: editingMessage)
            }
            
            if let fileURL, permissionStatus.canAttachFiles && permissionStatus.canSendMessages {
                filePreviewView(fileURL: fileURL)
            }
            
            if showingUploadPicker && permissionStatus.canAttachFiles && permissionStatus.canSendMessages {
                filePickerView
            }
            
            MessageBarView(
                permissionStatus: permissionStatus,
                placeholder: getPlaceholderText(),
                canSendCurrentMessage: canSendCurrentMessage,
                useNativePicker: useNativePicker,
                message: $message,
                showNativePicker: $showNativePicker,
                showNativePhotoPicker: $showNativePhotoPicker,
                showingFilePicker: $showingFilePicker,
                showingEmojiPicker: $showEmojiPicker,
                showingGIFPicker: $showGIFPicker,
                showingUploadPicker: $showingUploadPicker,
                onMessageChange: { _ in handleTypingIndicator() },
                onSubmit: handleMessageSubmit
            )
        }
    }
    
    @ViewBuilder
    var inputBackground: some View {
        if #available(iOS 19.0, *) {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .glassEffect(.clear)
                .opacity(0.92)
        } else {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }
    
    private var typingIndicatorView: some View {
        HStack {
            Group {
                let typing = user.guildManager.typingIndicators[currentid]?.filter { indicator in
                    let typingUserId = indicator.member?.id ?? indicator.user_id
                    return typingUserId != user.user?.id
                } ?? []
                
                if !typing.isEmpty {
                    if typing.count > 6 {
                        Text("Several people are typing...")
                    } else {
                        let names = typing.compactMap { indicator -> String? in
                            if let name = indicator.member?.user?.global_name ?? indicator.member?.user?.username {
                                return name
                            }
                            
                            if let dm = user.dms.first(where: { $0.id == currentid }),
                               let recipient = dm.recipients?.first(where: { $0.id == indicator.user_id }) {
                                return recipient.global_name ?? recipient.username
                            }
                            return nil
                        }
                        Text(formattedTypingText(for: names))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(inputBackground)
            .padding(.leading, 16)
            
            Spacer()
        }
    }
    
    func formattedTypingText(for users: [String]) -> String {
        switch users.count {
        case 0: return ""
        case 1: return "\(users[0]) is typing..."
        case 2: return "\(users[0]) and \(users[1]) are typing..."
        default:
            let allButLast = users.dropLast().joined(separator: ", ")
            return "\(allButLast) and \(users.last!) are typing..."
        }
    }
    
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    let messages = user.data[currentid] ?? []
                    
                    if canLoadOlderMessages, let firstMessage = messages.first {
                        olderMessagesLoader(before: firstMessage.messageId)
                    }
                    
                    ForEach(Array(messages.enumerated()), id: \.element.idForSwiftUI) { index, messageData in
                        let previousMessage = index > 0 ? messages[index - 1] : nil
                        
                        if let previousMessage, user.isDividerNeeded(for: messageData, from: previousMessage) {
                            HStack {
                                VStack {
                                    Divider()
                                        .frame(height: 1)
                                }
                                
                                Text(user.dateFromSnowflakeOp(messageData.messageId).formatted(date: .numeric, time: .shortened))
                                    .font(.caption)
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                VStack {
                                    Divider()
                                        .frame(height: 1)
                                }
                            }
                            .padding()
                            
                        }
                        
                        messageView(for: messageData, previousMessage: previousMessage, allMessages: messages)
                            .id(messageData.idForSwiftUI)
                    }
                }
                
                .padding(.top)
                .onAppear {
                    self.scrollProxy = proxy
                }
                .onChange(of: scrollToId) { newValue in
                    if let newValue,
                       let target = (user.data[currentid] ?? []).first(where: { $0.messageId == newValue }) {
                        proxy.scrollTo(target.idForSwiftUI, anchor: pendingScrollAnchor)
                        pendingScrollAnchor = nil
                        self.scrollToId = nil
                    }
                }
                .onChange(of: finished) { newValue in
                    if newValue, let last = (user.data[currentid] ?? []).last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            proxy.scrollTo(last.idForSwiftUI, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .scrollAnchorBottom(userService: user, scrollproxy: proxy)
        }
    }
    
    @ViewBuilder
    private func olderMessagesLoader(before messageId: String) -> some View {
        Group {
            if isLoadingOlderMessages {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 8)
            } else {
                Color.clear
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            Task {
                await loadOlderMessages(before: messageId)
            }
        }
    }
    
    @ViewBuilder
    private func messageView(for messageData: Message, previousMessage: Message?, allMessages: [Message]) -> some View {
        let isCurrentUser = user.user?.id == messageData.author.authorId
        let alignment: HorizontalAlignment = (messageStyle == .default && !useRedesignedMessages) || !isCurrentUser ? .leading : .trailing
        
        VStack(alignment: alignment, spacing: 2) {
            Group {
                if useRedesignedMessages {
                    let isGrouped = MessageViewRE.shouldGroupMessage(current: messageData, previous: previousMessage)
                    
                    MessageViewRE(
                        messageData: messageData,
                        currentChannel: currentGuild?.id ?? "",
                        reply: $scrollToId,
                        webSocketService: webSocketService,
                        isCurrentUser: isCurrentUser,
                        onProfileTap: { presentUserProfile(for: messageData.author) },
                        isGrouped: isGrouped,
                        allMessages: allMessages
                    )
                } else {
                    MessageView(
                        messageData: messageData,
                        currentChannel: currentGuild?.id ?? "",
                        reply: $scrollToId,
                        webSocketService: webSocketService,
                        isCurrentUser: isCurrentUser && messageStyle != .default,
                        onProfileTap: { presentUserProfile(for: messageData.author) }
                    )
                }
            }
            .contextMenu {
                Text(user.dateFromSnowflakeOp(messageData.messageId).formatted(date: .numeric, time: .shortened))
                
                if messageData.editedtimestamp != nil {
                    Text("Edited")
                }
                
                Button { presentUserProfile(for: messageData.author) } label: {
                    Label("Show User", systemImage: "person")
                }
                
                if isCurrentUser {
                    Button {
                        editMessage = messageData
                        message = messageData.content
                    } label: {
                        Label("Edit Message", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        Task { try? await discordAPI.makeRequest(.deleteMessage(channel: currentid, messageId: messageData.messageId)) }
                    } label: {
                        Label("Delete Message", systemImage: "trash")
                    }
                }
                
                Button { repliedMessage = messageData } label: {
                    Label("Reply", systemImage: isCurrentUser ? "arrowshape.turn.up.left" : "arrowshape.turn.up.right")
                }
                
                Button {
                    reactMessage = messageData
                } label: {
                    Label("React", systemImage: "face.smiling.inverse")
                }
            }
        }
    }
    
    private func addReaction(_ emoji: Emoji, messageData: Message) {
        Task {
            do {
                try await discordAPI.makeRequest(
                    .addReaction(channelId: messageData.channelId, messageId: messageData.messageId, emoji: emoji)
                )
            } catch {
                print("Reaction update failed: \(error)")
            }
        }
    }
    
    @ViewBuilder
    private func membersView(_ proxy: GeometryProxy) -> some View {
        if showMembers, let currentGuild, UIDevice.current.userInterfaceIdiom == .pad {
            List {
                membersSections(for: currentGuild, showAll: true)
                
                Section {
                    Button("All Members") {
                        webSocketService.requestGuildMembers(guildID: currentGuild.id, limit: 0)
                        showAllMembers = true
                        showMembersSheet = true
                    }
                }
            }
            .frame(width: proxy.size.width / 3)
            .animation(.easeInOut)
        }
    }
    
    private struct ProcessedRoleSection: Identifiable {
        let id: String
        let roleName: String
        let members: [GuildMember]
    }
    
    @State private var processedSections: [ProcessedRoleSection] = []
    
    @ViewBuilder
    private func membersSections(for guild: Guild, showAll: Bool) -> some View {
        ForEach(processedSections) { section in
            Section(section.roleName + " — " + String(section.members.count)) {
                ForEach(section.members) { member in
                    if let memberUser = member.user {
                        UserView(presence: user.presenceByUserId[memberUser.id], user: memberUser)
                    }
                }
            }
        }
        .onAppear {
            if let currentGuild { recomputeMemberSections(for: currentGuild) }
        }
    }
    
    @State private var processedUnhoistedMembers: [GuildMember] = []
    
    private func recomputeMemberSections(for guild: Guild) {
        let allMembers = user.guildManager.members[guild.id] ?? []
        let roles = user.guildManager.roles[array: guild.id]
        let presences = user.presenceByUserId
        
        DispatchQueue.global(qos: .userInitiated).async {
            let hoistedRoleIds = Set(roles.filter { $0.hoist }.map(\.id))
            var visibleRoles: [String: Set<GuildMember>] = Dictionary(
                uniqueKeysWithValues: hoistedRoleIds.map { ($0, Set<GuildMember>()) }
            )
            
            for member in allMembers {
                guard let roleId = roles.first(where: { $0.hoist && member.roles.contains($0.id) })?.id else { continue }
                visibleRoles[roleId]?.insert(member)
            }
            
            let visibleRoleIds = Set(visibleRoles.keys)
            let hoistedRoles = roles.filter { $0.hoist }
            
            let sections: [ProcessedRoleSection] = hoistedRoles.compactMap { role in
                let members = visibleRoles[role.id, default: []]
                let onlineMembers = members
                    .filter {
                        let status = presences[$0.id]?.status
                        return status?.isEmpty == false && status != "offline"
                    }
                    .sorted { ($0.user?.username ?? "") < ($1.user?.username ?? "") }
                
                guard !onlineMembers.isEmpty else { return nil }
                return ProcessedRoleSection(id: role.id, roleName: role.name, members: onlineMembers)
            }
            
            let onlineUnhoisted = allMembers
                .filter { !$0.roles.contains(where: { visibleRoleIds.contains($0) }) }
                .filter {
                    let status = presences[$0.id]?.status
                    return status?.isEmpty == false && status != "offline"
                }
                .sorted { ($0.user?.username ?? "") < ($1.user?.username ?? "") }
            
            DispatchQueue.main.async {
                self.processedSections = sections
                self.processedUnhoistedMembers = onlineUnhoisted
            } 
        }
    }
    
    @ViewBuilder
    private func unhoistedMembersSection(for guild: Guild) -> some View {
        Section("Online — \(processedUnhoistedMembers.count)") {
            ForEach(processedUnhoistedMembers) { member in
                if let memberUser = member.user {
                    UserView(presence: user.presenceByUserId[memberUser.id], user: memberUser)
                }
            }
        }
    }
    
    private func filePreviewView(fileURL: URL) -> some View {
        VStack(alignment: .trailing) {
            Button { self.fileURL = nil } label: {
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
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Text(replyMessage.content)
                            .font(.footnote)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button { self.repliedMessage = nil } label: {
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
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Text(editingMessage.content)
                            .font(.footnote)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    message = ""
                    self.editMessage = nil
                } label: {
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
                    Button {
                        if permissionStatus.canAttachFiles {
                            showNativePhotoPicker = true
                        }
                    } label: {
                        Label("Photo", systemImage: "photo")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(permissionStatus.canAttachFiles ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .foregroundColor(permissionStatus.canAttachFiles ? .blue : .gray)
                            .cornerRadius(8)
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
                
                Button { showingUploadPicker = false } label: {
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
        permissionStatus.canSendMessages && (!message.isEmpty || (fileURL != nil && permissionStatus.canAttachFiles))
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
        let channel = currentid
        let staticMessage = contentForSending(message)
        let repliedMessageAsync = repliedMessage
        let capturedFileURL = self.fileURL
        let editMessage = self.editMessage
        
        message = ""
        repliedMessage = nil
        self.editMessage = nil
        self.fileURL = nil
        showingFilePicker = false
        
        Task {
            let didStartScope = capturedFileURL?.startAccessingSecurityScopedResource() ?? false
            defer {
                if didStartScope { capturedFileURL?.stopAccessingSecurityScopedResource() }
                if let capturedFileURL {
                    removeTemporaryUpload(at: capturedFileURL)
                }
            }
            
            do {
                if let repliedMessage = repliedMessageAsync {
                    try await discordAPI.makeRequest(
                        .sendMessage(channel: channel, content: staticMessage, fileURL: capturedFileURL,
                                     messageReference: ["message_id": repliedMessage.messageId])
                    )
                } else if let editMessage {
                    try await discordAPI.makeRequest(
                        .editMessage(channel: channel, messageId: editMessage.messageId, content: staticMessage)
                    )
                } else {
                    try await discordAPI.makeRequest(
                        .sendMessage(channel: channel, content: staticMessage, fileURL: capturedFileURL)
                    )
                }
            } catch {
                print("Send/edit message failed: \(error)")
            }
        }
    }
    
    private func sendGIF(_ gif: FavoriteGIF) {
        guard permissionStatus.canSendMessages else {
            return
        }
        
        let channel = currentid
        let content = gif.sendURL
        let repliedMessageAsync = repliedMessage
        let editMessage = self.editMessage
        
        message = ""
        repliedMessage = nil
        self.editMessage = nil
        self.fileURL = nil
        showingFilePicker = false
        showingUploadPicker = false
        
        Task {
            do {
                if let repliedMessage = repliedMessageAsync {
                    _ = try await discordAPI.makeRequest(
                        .sendMessage(channel: channel, content: content, messageReference: ["message_id": repliedMessage.messageId])
                    )
                } else if let editMessage {
                    _ = try await discordAPI.makeRequest(
                        .editMessage(channel: channel, messageId: editMessage.messageId, content: content)
                    )
                } else {
                    _ = try await discordAPI.makeRequest(
                        .sendMessage(channel: channel, content: content)
                    )
                }
            } catch { }
        }
    }
    
    private func refreshMessages() async {
        do {
            let guildArg = currentGuild?.id ?? currentid
            let existingMessages = await MainActor.run { user.data[currentid] ?? [] }
            
            if let latestInMemory = existingMessages.last?.messageId {
                let messages = try await discordAPI.makeRequest(.messages, args: [currentid, guildArg, latestInMemory])
                let normalized = normalizedMessages(Array(messages.reversed()))
                
                await MainActor.run {
                    user.mergeMessages(normalized, into: currentid)
                    finished = true
                }
                acknowledgeLatestLoadedMessage()
                return
            }
            
            let recentMessages = try await discordAPI.makeRequest(.messages, args: [currentid, guildArg])
            var normalized = normalizedMessages(Array(recentMessages.reversed()))
            
            let latestStored = await MainActor.run { user.latestMessageId(for: currentid) }
            if let latestStored {
                let missedMessages = (try? await discordAPI.makeRequest(.messages, args: [currentid, guildArg, latestStored])) ?? []
                normalized.append(contentsOf: normalizedMessages(Array(missedMessages.reversed())))
            }
            
            await MainActor.run {
                user.data[currentid] = []
                user.mergeMessages(normalized, into: currentid)
                finished = true
            }
            acknowledgeLatestLoadedMessage()
        } catch {
            print("Message refresh failed: \(error)")
        }
    }
    
    @MainActor
    private func loadOlderMessages(before oldestMessageId: String) async {
        guard !isLoadingOlderMessages, canLoadOlderMessages else { return }
        guard oldestLoadedCursor != oldestMessageId else { return }
        
        isLoadingOlderMessages = true
        oldestLoadedCursor = oldestMessageId
        defer { isLoadingOlderMessages = false }
        
        do {
            let guildArg = currentGuild?.id ?? currentid
            let messages: [Message] = try await discordAPI.makeRequest(
                .messages,
                args: [currentid, guildArg, nil, oldestMessageId, 100]
            )
            let normalized = normalizedMessages(Array(messages.reversed()))
            
            guard !normalized.isEmpty else {
                canLoadOlderMessages = false
                return
            }
            
            user.mergeMessages(normalized, into: currentid)
            canLoadOlderMessages = messages.count >= 100
            pendingScrollAnchor = .top
            scrollToId = oldestMessageId
        } catch {
            oldestLoadedCursor = nil
            print("Older message load failed: \(error)")
        }
    }
    
    private func acknowledgeLatestLoadedMessage() {
        guard let messageId = user.data[currentid]?.last?.messageId else { return }
        user.acknowledgeMessage(channelId: currentid, messageId: messageId)
    }
    
    private func normalizedMessages(_ messages: [Message]) -> [Message] {
        guard let currentGuild else { return messages }
        var normalized = messages
        for index in normalized.indices where normalized[index].guildId == nil {
            normalized[index].guildId = currentGuild.id
        }
        return normalized
    }
    
    private func insertEmoji(_ emoji: Emoji) {
        if user.hasNitro || canUseEmojiWithoutNitro(emoji) {
            if let shortcode = emoji.discordShortcode {
                message.append(shortcode)
            }
        } else if allowFakeNitroEmojis, let fakeNitro = emoji.fakeNitroMarkdown {
            if !message.isEmpty, !message.hasSuffix(" ") {
                message.append(" ")
            }
            message.append(fakeNitro)
            message.append(" ")
        }
    }
    
    private func canUseEmojiWithoutNitro(_ emoji: Emoji) -> Bool {
        guard emoji.animated != true else { return false }
        guard let id = emoji.id else { return true }
        guard let guildId = currentGuild?.id else { return false }
        return user.guildManager.emojis[guildId]?.contains(where: { $0.id == id }) == true
    }
    
    private func contentForSending(_ content: String) -> String {
        let content = contentByResolvingEmojiShortcodes(in: content)
        
        guard !user.hasNitro else { return content }
        guard allowFakeNitroEmojis else { return content }
        
        let regex = try! NSRegularExpression(pattern: #"<(a?):([A-Za-z0-9_]+):(\d+)>"#)
        let nsContent = content as NSString
        let result = NSMutableString()
        var lastLocation = 0
        
        regex.enumerateMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content)) { match, _, _ in
            guard let match,
                  let animatedRange = Range(match.range(at: 1), in: content),
                  let nameRange = Range(match.range(at: 2), in: content),
                  let idRange = Range(match.range(at: 3), in: content) else { return }
            
            result.append(nsContent.substring(with: NSRange(location: lastLocation, length: match.range.location - lastLocation)))
            
            let id = String(content[idRange])
            let name = String(content[nameRange])
            let animated = !content[animatedRange].isEmpty
            
            if canUseEmojiWithoutNitro(Emoji(id: id, name: name, user: nil, roles: nil, available: nil, animated: animated, require_colons: nil, managed: nil, version: nil)) {
                result.append(nsContent.substring(with: match.range))
            } else {
                let emoji = Emoji(id: id, name: name, user: nil, roles: nil, available: nil, animated: animated, require_colons: nil, managed: nil, version: nil)
                result.append(emoji.fakeNitroMarkdown ?? nsContent.substring(with: match.range))
            }
            
            lastLocation = match.range.location + match.range.length
        }
        
        result.append(nsContent.substring(from: lastLocation))
        return result as String
    }
    
    private func contentByResolvingEmojiShortcodes(in content: String) -> String {
        let fullEmojiRegex = try! NSRegularExpression(pattern: #"<a?:[A-Za-z0-9_]+:\d+>"#)
        let existingEmojiRanges = fullEmojiRegex
            .matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            .map(\.range)
        
        let shortcodeRegex = try! NSRegularExpression(pattern: #":([A-Za-z0-9_]+):"#)
        let nsContent = content as NSString
        let result = NSMutableString()
        var lastLocation = 0
        
        shortcodeRegex.enumerateMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content)) { match, _, _ in
            guard let match else { return }
            
            result.append(nsContent.substring(with: NSRange(location: lastLocation, length: match.range.location - lastLocation)))
            
            defer {
                lastLocation = match.range.location + match.range.length
            }
            
            guard !existingEmojiRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else {
                result.append(nsContent.substring(with: match.range))
                return
            }
            
            let name = nsContent.substring(with: match.range(at: 1))
            guard let emoji = emoji(named: name) else {
                result.append(nsContent.substring(with: match.range))
                return
            }
            
            if user.hasNitro || canUseEmojiWithoutNitro(emoji) {
                result.append(emoji.discordShortcode ?? nsContent.substring(with: match.range))
            } else if allowFakeNitroEmojis {
                result.append(emoji.fakeNitroMarkdown ?? nsContent.substring(with: match.range))
            } else {
                result.append(nsContent.substring(with: match.range))
            }
        }
        
        result.append(nsContent.substring(from: lastLocation))
        return result as String
    }
    
    private func emoji(named name: String) -> Emoji? {
        if let guildId = currentGuild?.id,
           let emoji = user.guildManager.emojis[guildId]?.first(where: { $0.name == name }) {
            return emoji
        }
        
        return user.guildManager.emojis.values
            .flatMap { $0 }
            .first(where: { $0.name == name })
    }
    
    private func handleOnAppear() {
        guard let _ = keychain.get("token") else { return }
        TabBarModifier.shared.hideTabBar()
        
        
        Task { @MainActor in
            user.guildManager.currentChannel = currentid
            
            if let currentGuild { recomputeMemberSections(for: currentGuild) }
            
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                Task {
                    await refreshMessages()
                }
            }
            
            if !currentchannelname.starts(with: "@") && user.guildManager.members.isEmpty {
                if let currentGuild {
                    webSocketService.requestGuildMembers(guildID: currentGuild.id)
                }
            }
            
            if let currentGuild {
                let roles = try? await discordAPI.makeRequest(.roles, args: [currentGuild.id])
                self.user.guildManager.roles[currentGuild.id] = roles ?? []
                self.updatePermissions()
            }
            
            updatePermissions()
        }
    }
    
    private func handleOnDisappear() {
        permissionUpdateWorkItem?.cancel()
        permissionUpdateWorkItem = nil
        user.guildManager.currentChannel = ""
        if let messages = user.data[currentid] {
            user.rememberLatestMessage(in: currentid, from: messages)
            if let messageId = messages.last?.messageId {
                user.acknowledgeMessage(channelId: currentid, messageId: messageId)
            }
        }
        TabBarModifier.shared.showTabBar()
    }
    
    private func handleTypingIndicator() {
        guard message.count > 3 else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastTypingSent) >= 10 else { return }
        
        lastTypingSent = now
        
        Task {
            _ = try? await discordAPI.makeRequest(.typingIndicator, args: [currentid])
        }
    }
    
    private func handleTabChange(isActive: Bool) {
        if isActive {
            finished = false
            guard !user.token.isEmpty else { return }
            user.guildManager.currentChannel = currentid
            
            Task { @MainActor in
                await refreshMessages()
                
                if let currentGuild {
                    let roles = (try? await discordAPI.makeRequest(.roles, args: [currentGuild.id])) ?? []
                    self.user.guildManager.roles[currentGuild.id] = roles
                    self.updatePermissions()
                }
            }
            
            updatePermissions()
        } else {
            user.guildManager.currentChannel = ""
            user.guildManager.roles.removeAll()
        }
    }
    
    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            
            let fileManager = FileManager.default
            let targetURL = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent(url.lastPathComponent)
            
            do {
                try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: url, to: targetURL)
                self.fileURL = targetURL
                self.showingUploadPicker = false
            } catch {
                print("Failed to save file: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            print("File import error: \(error.localizedDescription)")
        }
    }
    
    /*
     private func handlePhotoSelection(_ item: PhotosPickerItem?) {
     guard let item else { return }
     
     Task {
     guard let data = try? await item.loadTransferable(type: Data.self) else { return }
     
     let fileName = item.itemIdentifier ?? UUID().uuidString
     let fileExtension = getFileExtension(for: item)
     let tempURL = FileManager.default.temporaryDirectory
     .appendingPathComponent(UUID().uuidString)
     .appendingPathComponent("\(fileName).\(fileExtension)")
     
     do {
     try FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
     try data.write(to: tempURL)
     
     await MainActor.run {
     self.fileURL = tempURL
     self.showingUploadPicker = false
     }
     } catch {
     print("Failed to save photo: \(error.localizedDescription)")
     }
     }
     }
     
     private func getFileExtension(for item: PhotosPickerItem) -> String {
     guard let contentType = item.supportedContentTypes.first else { return "jpg" }
     if contentType.conforms(to: .image) { return "jpg" }
     if contentType.conforms(to: .movie) { return "mp4" }
     return "jpg"
     }
     */
    
    private func removeTemporaryUpload(at url: URL) {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.standardizedFileURL
        let uploadURL = url.standardizedFileURL
        
        guard uploadURL.path.hasPrefix(tempDirectory.path) else { return }
        
        let uploadDirectory = uploadURL.deletingLastPathComponent().standardizedFileURL
        let cleanupURL = uploadDirectory.path == tempDirectory.path ? uploadURL : uploadDirectory
        
        do {
            try fileManager.removeItem(at: cleanupURL)
        } catch {
            print("Error removing temporary upload: \(error.localizedDescription)")
        }
    }
    
    private func presentUserProfile(for author: Author) {
        if !Thread.isMainThread {
            Task { @MainActor in self.presentUserProfile(for: author) }
            return
        }
        
        if let cached = CacheService.shared.getCachedUserProfile(userId: author.authorId) {
            selectedUserProfile = cached
            isLoadingProfile = false
        } else {
            selectedUserProfile = nil
            isLoadingProfile = true
        }
        
        selectedAuthor = author
        fetchUserProfile(userId: author.authorId, useCache: false)
    }
    
    private func fetchUserProfile(userId: String, useCache: Bool = true) {
        if useCache, let cached = CacheService.shared.getCachedUserProfile(userId: userId) {
            Task { @MainActor in
                self.selectedUserProfile = cached
                self.isLoadingProfile = false
            }
            return
        }
        
        guard !user.token.isEmpty else {
            Task { @MainActor in self.isLoadingProfile = false }
            return
        }
        
        Task { @MainActor in
            if self.selectedUserProfile == nil {
                self.isLoadingProfile = true
            }
        }
        
        Task {
            let profile = try? await discordAPI.makeRequest(.userProfile, args: [userId])
            
            if let profile {
                CacheService.shared.setCachedUserProfile(profile, userId: userId)
                Task { @MainActor in
                    self.selectedUserProfile = profile
                    self.isLoadingProfile = false
                }
            } else {
                let basicUser = try? await discordAPI.makeRequest(.basicUser, args: [userId])
                Task { @MainActor in
                    if let basicUser {
                        self.selectedUserProfile = UserProfile(
                            user: basicUser,
                            connectedAccounts: nil,
                            premiumSince: nil,
                            premiumType: nil,
                            premiumGuildSince: nil,
                            profileThemesExperimentBucket: nil,
                            mutualGuilds: nil,
                            mutualFriends: nil,
                            userProfile: nil
                        )
                    }
                    self.isLoadingProfile = false
                }
            }
        }
    }
    
    private func schedulePermissionsUpdate() {
        permissionUpdateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            updatePermissions()
        }
        
        permissionUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
    
    private func updatePermissions() {
        if let currentGuild { recomputeMemberSections(for: currentGuild) }
        
        guard let guildId = currentGuild?.id else { return }
        
        guard !ignoreChatPermissions else {
            permissionStatus = ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
            return
        }
        
        guard !currentchannelname.starts(with: "@") else {
            permissionStatus = ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
            return
        }
        
        guard !(user.user?.id ?? "").isEmpty else {
            permissionStatus = ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: nil)
            return
        }
        
        let currentChannels = user.channels(forGuild: guildId)
        let currentChannel = resolveCurrentChannel(from: currentChannels)
        let parentChannel = currentChannel?.parentId.flatMap { parentId in
            user.channel(withId: parentId)
        }
        
        permissionStatus = PermissionManager.getPermissionStatus(
            currentUser: user.user ?? User(id: "", username: "", discriminator: "", avatar: ""),
            members: user.guildManager.members[guildId] ?? [],
            roles: user.guildManager.roles[array: guildId],
            channel: currentChannel,
            guildId: guildId,
            categoryOverwrites: parentChannel?.permissionOverwrites
        )
    }
    
    private func resolveCurrentChannel(from channels: [Channel]) -> Channel? {
        if let channel = channels.first(where: { $0.id == currentid }) {
            return channel
        }
        
        return user.channel(withId: currentid)
    }
}

struct ScrollLock: ViewModifier {
    var webSocketService: CurrentUserService
    var scrollViewProxy: ScrollViewProxy
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
    }
}

extension View {
    func scrollAnchorBottom(userService: CurrentUserService, scrollproxy: ScrollViewProxy) -> some View {
        self.modifier(ScrollLock(webSocketService: userService, scrollViewProxy: scrollproxy))
    }
}

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
            guard let window = notification.object as? NSWindow, window == currentWindow else { return }
            isActiveTab = true
            onTabChange(true)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow, window == currentWindow else { return }
            isActiveTab = false
            onTabChange(false)
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignMainNotification, object: nil)
    }
}

extension View {
    func detectTabChanges(onChange: @escaping (Bool) -> Void) -> some View {
        modifier(WindowTabObserver(onTabChange: onChange))
    }
}
#endif

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

extension View {
    func channelSheets(
        showMembersSheet: Binding<Bool>,
        showAllMembers: Binding<Bool>,
        showNativePhotoPicker: Binding<Bool>,
        showGIFPicker: Binding<Bool>,
        reactMessage: Binding<Message?>,
        currentGuild: Guild?,
        permissionStatus: ChannelPermissionStatus,
        onRequestAllMembers: @escaping () -> Void,
        onPhotoSaved: @escaping (URL) -> Void,
        onPhotoCancel: @escaping () -> Void,
        onGIFSelected: @escaping (FavoriteGIF) -> Void,
        onReactionSelected: @escaping (Emoji?, NativeEmoji?, Message) -> Void,
        membersSections: @escaping (Guild) -> AnyView,
        unhoistedMembersSection: @escaping (Guild) -> AnyView
    ) -> some View {
        modifier(
            ChannelSheetsModifier(
                showMembersSheet: showMembersSheet,
                showAllMembers: showAllMembers,
                showNativePhotoPicker: showNativePhotoPicker,
                showGIFPicker: showGIFPicker,
                reactMessage: reactMessage,
                currentGuild: currentGuild,
                permissionStatus: permissionStatus,
                onRequestAllMembers: onRequestAllMembers,
                onPhotoSaved: onPhotoSaved,
                onPhotoCancel: onPhotoCancel,
                onGIFSelected: onGIFSelected,
                onReactionSelected: onReactionSelected,
                membersSections: membersSections,
                unhoistedMembersSection: unhoistedMembersSection
            )
        )
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private struct ChannelSheetsModifier: ViewModifier {
    @Binding var showMembersSheet: Bool
    @Binding var showAllMembers: Bool
    @Binding var showNativePhotoPicker: Bool
    @Binding var showGIFPicker: Bool
    @Binding var reactMessage: Message?
    @State private var activeSheet: ChannelSheet?
    
    let currentGuild: Guild?
    let permissionStatus: ChannelPermissionStatus
    let onRequestAllMembers: () -> Void
    let onPhotoSaved: (URL) -> Void
    let onPhotoCancel: () -> Void
    let onGIFSelected: (FavoriteGIF) -> Void
    let onReactionSelected: (Emoji?, NativeEmoji?, Message) -> Void
    let membersSections: (Guild) -> AnyView
    let unhoistedMembersSection: (Guild) -> AnyView
    
    func body(content: Content) -> some View {
        content
            .onChange(of: showMembersSheet) { isPresented in
                if isPresented {
                    activeSheet = .members
                } else if activeSheet?.isMembers == true {
                    activeSheet = nil
                }
            }
            .onChange(of: showNativePhotoPicker) { isPresented in
                if isPresented {
                    activeSheet = .photoPicker
                } else if activeSheet?.isPhotoPicker == true {
                    activeSheet = nil
                }
            }
            .onChange(of: showGIFPicker) { isPresented in
                if isPresented {
                    activeSheet = .gifPicker
                } else if activeSheet?.isGIFPicker == true {
                    activeSheet = nil
                }
            }
            .onChange(of: reactMessage) { message in
                if let message {
                    activeSheet = .reaction(message)
                } else if activeSheet?.isReaction == true {
                    activeSheet = nil
                }
            }
            .sheet(item: $activeSheet, onDismiss: dismissActiveSheet) { sheet in
                sheetContent(for: sheet)
            }
    }
    
    private func dismissActiveSheet() {
        showMembersSheet = false
        showNativePhotoPicker = false
        showGIFPicker = false
        reactMessage = nil
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: ChannelSheet) -> some View {
        switch sheet {
        case .members:
            if let currentGuild {
                List {
                    membersSections(currentGuild)
                    
                    if UIDevice.current.userInterfaceIdiom != .pad {
                        Section {
                            Button("All Members") {
                                onRequestAllMembers()
                                showAllMembers.toggle()
                            }
                        }
                    }
                    
                    if UIDevice.current.userInterfaceIdiom == .pad || showAllMembers {
                        unhoistedMembersSection(currentGuild)
                    }
                }
                .compatPresentationDragIndicator()
            }
        case .photoPicker:
            PhotoPickerView(
                onImageSaved: { savedImageURL in
                    onPhotoSaved(savedImageURL)
                    activeSheet = nil
                },
                onCancel: {
                    onPhotoCancel()
                    activeSheet = nil
                }
            )
            .compatPresentationDragIndicator()
        case .gifPicker:
            GIFPickerView { gif in
                onGIFSelected(gif)
                activeSheet = nil
            }
            .compatPresentationDetentsMedium()
            .compatPresentationDragIndicator()
        case .reaction(let message):
            NativeEmojiView { emoji, nativeEmoji in
                onReactionSelected(emoji, nativeEmoji, message)
                activeSheet = nil
            }
            .compatPresentationDetentsMedium()
            .compatPresentationDragIndicator()
        }
    }
}

private enum ChannelSheet: Identifiable {
    case members
    case photoPicker
    case gifPicker
    case reaction(Message)
    
    var id: String {
        switch self {
        case .members:
            return "members"
        case .photoPicker:
            return "photo-picker"
        case .gifPicker:
            return "gif-picker"
        case .reaction(let message):
            return "reaction-\(message.idForSwiftUI)"
        }
    }
    
    var isMembers: Bool {
        if case .members = self { return true }
        return false
    }
    
    var isPhotoPicker: Bool {
        if case .photoPicker = self { return true }
        return false
    }
    
    var isGIFPicker: Bool {
        if case .gifPicker = self { return true }
        return false
    }
    
    var isReaction: Bool {
        if case .reaction = self { return true }
        return false
    }
}

extension View {
    @ViewBuilder
    func compatPresentationDetentsMediumLarge() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large])
        } else {
            self
        }
    }
    
    @ViewBuilder
    func compatPresentationDetentsMedium() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium])
        } else {
            self
        }
    }
    
    @ViewBuilder
    func compatPresentationDragIndicator() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

extension Message {
    var idForSwiftUI: String {
        "\(messageId)-\(editedtimestamp ?? "original")"
    }
}
