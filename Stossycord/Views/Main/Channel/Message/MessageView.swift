//
//  MessageView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation
import MarkdownUI
#if os(iOS)
import Giffy
#endif

struct MessageView: View {
    let messageData: Message
    let currentChannel: String
    @Binding var reply: String?
    @StateObject var webSocketService: WebSocketService
    @EnvironmentObject var userSession: CurrentUserService
    let isCurrentUser: Bool
    let onProfileTap: (() -> Void)?
    
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = MessageBubbleStyle.imessage.rawValue
    
    var messageStyle: MessageBubbleStyle {
        .init(rawValue: messageStyleRawValue) ?? .imessage
    }
    
    @State private var roleColor: Color = .primary
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            let isMessage = isMessageAbove()
            if isCurrentUser { Spacer(minLength: 60) }
            
            if !isCurrentUser {
                if isMessage {
                    Spacer()
                        .frame(width: 36, height: 36)
                } else {
                    AvatarView(author: messageData.author, onProfileTap: onProfileTap)
                }
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                if let replyId = messageData.messageReference?.messageId {
                    ReplyIndicatorView(
                        messageId: replyId,
                        webSocketService: webSocketService,
                        isCurrentUser: isCurrentUser,
                        reply: $reply
                    )
                }
                
                if !isMessageAbove() {
                    AuthorHeaderView(
                        author: messageData.author,
                        editedTimestamp: messageData.editedtimestamp,
                        roleColor: roleColor,
                        isCurrentUser: isCurrentUser
                    )
                }
                
                if !messageData.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MessageContentView(
                        messageData: messageData,
                        isCurrentUser: isCurrentUser
                    )
                }
                
                if let embeds = messageData.embeds, !embeds.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(embeds, id: \.self) { embed in
                            EmbedCardView(embed: embed, isCurrentUser: isCurrentUser)
                        }
                    }
                }
                
                if let attachments = messageData.attachments, !attachments.isEmpty {
                    HStack {
                        attachmentsView(attachments: attachments)
                    }
                    .padding()
                }
                
                if let poll = messageData.poll {
                    PollMessageView(
                        message: messageData,
                        webSocketService: webSocketService,
                        poll: poll,
                        isCurrentUser: isCurrentUser
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
            
            if isCurrentUser {
                if isMessage {
                    Spacer()
                        .frame(width: 36, height: 36)
                } else {
                    AvatarView(author: messageData.author, onProfileTap: onProfileTap)
                }
            }
            
            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear { loadRoleColor() }
    }
    
    private func attachmentsView(attachments: [Attachment]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(attachments, id: \.id) { attachment in
                GeometryReader { geo in
                    let displaySize = attachmentDisplaySize(for: attachment, availableWidth: geo.size.width)
                    
                    MediaView(attachment: attachment, isCurrentUser: isCurrentUser, maxDimension: max(displaySize.width, displaySize.height))
                        .cornerRadius(8)
                        .frame(width: displaySize.width, height: displaySize.height)
                        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                }
                .frame(height: {
                    attachmentDisplaySize(
                        for: attachment,
                        availableWidth: UIScreen.main.bounds.width * 0.75
                    ).height
                }())
                .cornerRadius(8)
            }
        }
    }
    
    private func attachmentDisplaySize(for attachment: Attachment, availableWidth: CGFloat) -> CGSize {
        let maxHeight: CGFloat = 360
        let maxWidth = max(1, min(availableWidth, UIScreen.main.bounds.width * 0.9))
        
        guard let width = attachment.width,
              let height = attachment.height,
              width > 0,
              height > 0 else {
            return CGSize(width: min(maxWidth, 300), height: 200)
        }
        
        let aspectRatio = CGFloat(width) / CGFloat(height)
        var displayWidth = min(maxWidth, maxHeight * aspectRatio)
        var displayHeight = displayWidth / aspectRatio
        
        if displayHeight > maxHeight {
            displayHeight = maxHeight
            displayWidth = displayHeight * aspectRatio
        }
        
        return CGSize(width: max(1, displayWidth), height: max(1, displayHeight))
    }
    
    private func isMessageAbove() -> Bool {
        if let messages = userSession.data[messageData.channelId],
           let messageIndex = messages.firstIndex(where: { $0.messageId == messageData.messageId }),
           let message = messages[safe: (messageIndex - 1)], message.author.id == messageData.author.id {
            if abs(snowflakeToDate(messageData.messageId) .timeIntervalSince(snowflakeToDate(message.messageId))) <= 30 * 60 {
                return messageData.messageReference?.messageId == nil && messageData.attachments?.isEmpty ?? true && messageData.embeds?.isEmpty ?? true && messageData.poll == nil
            }
        }
        
        return false
    }
    
    private func loadRoleColor() {
        guard let guildId = messageData.guildId else { return }
        
        let members = userSession.guildManager.members[guildId] ?? []
        let roles = userSession.guildManager.roles[array: guildId]
        let authorId = messageData.author.authorId
        
        Task.detached(priority: .utility) {
            guard let member = members.first(where: { $0.user?.id == authorId || $0.userId == authorId }) else { return }
            
            let matchedRoles = roles.filter { member.roles.contains($0.id) }
            let roleColor = matchedRoles.first(where: { $0.color != 0 })
                .flatMap { Color(hex: $0.color) } ?? Color.primary
            
            await MainActor.run { self.roleColor = roleColor }
        }
    }
    
    func snowflakeToDate(_ snowflake: String) -> Date {
        let discordEpoch: UInt64 = 1420070400000 // Jan 1, 2015 in ms
        let timestamp = (UInt64(snowflake) ?? 0 >> 22) + discordEpoch
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }
}

struct AvatarView: View {
    let author: Author
    let onProfileTap: (() -> Void)?
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    @AppStorage(DesignSettingsKeys.hideProfilePictures) private var hideProfilePictures: Bool = false
    
    var body: some View {
        if hideProfilePictures {
            EmptyView()
        } else if let url = avatarURL {
            let shouldAnimate = author.animated && !disableAnimatedAvatars
            if shouldAnimate {
#if os(iOS)
                AsyncGiffy(url: url) { phase in
                    switch phase {
                    case .loading:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView().scaleEffect(0.6))
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    case .error:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    case .success(let giffy):
                        giffy
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipped()
                            .clipShape(Circle())
                    }
                }
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
#else
                AnimatedWebImage(url: url)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .onTapGesture {
                        if !disableProfilePictureTap {
                            onProfileTap?()
                        }
                    }
#endif
            } else {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
            }
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 36)
                .onTapGesture {
                    if !disableProfilePictureTap {
                        onProfileTap?()
                    }
                }
        }
    }
    
    private var avatarURL: URL? {
        if let avatar = author.avatarHash {
            // If animations are disabled, request PNG — Discord returns the first frame for animated avatars when requested as PNG
            let shouldAnimate = author.animated && !disableAnimatedAvatars
            if shouldAnimate {
                return URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).gif?size=1024&animated=true")
            }
            return URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).png")
        } else {
            return URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")
        }
    }
}

extension Color {
    init?(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}
