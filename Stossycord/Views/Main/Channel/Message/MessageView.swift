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
    @Binding var reply: String?
    @StateObject var webSocketService: WebSocketService
    let isCurrentUser: Bool
    let onProfileTap: (() -> Void)?
    
    @State private var roleColor: Color = .primary
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isCurrentUser { Spacer(minLength: 60) }
            
            if !isCurrentUser {
                AvatarView(author: messageData.author, onProfileTap: onProfileTap)
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
                
                AuthorHeaderView(
                    author: messageData.author,
                    editedTimestamp: messageData.editedtimestamp,
                    roleColor: roleColor,
                    isCurrentUser: isCurrentUser
                )
                
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
                AvatarView(author: messageData.author, onProfileTap: onProfileTap)
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
                MediaView(url: attachment.url, isCurrentUser: isCurrentUser)
                    .cornerRadius(8)
                    .frame(maxHeight: 300)
            }
        }
    }
    
    private func loadRoleColor() {
        guard let member = webSocketService.currentMembers.first(where: { $0.user.id == messageData.author.authorId }) else {
            return
        }
        
        let roles = member.roles
        
        if let role = roles.compactMap({ roleId in
            webSocketService.currentroles.first { $0.id == roleId && $0.color != 0 }
        }).first {
            roleColor = Color(hex: role.color) ?? .primary
        }
    }
}

struct AvatarView: View {
    let author: Author
    let onProfileTap: (() -> Void)?
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    
    var body: some View {
        if let url = avatarURL {
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

struct AuthorHeaderView: View {
    let author: Author
    let editedTimestamp: String?
    let roleColor: Color
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            if !isCurrentUser {
                Text(author.currentname)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(roleColor)
                
                if editedTimestamp != nil {
                    Text("(edited)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                if editedTimestamp != nil {
                    Text("(edited)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(author.currentname)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(roleColor)
            }
        }
    }
}

struct ReplyIndicatorView: View {
    let messageId: String
    @StateObject var webSocketService: WebSocketService
    let isCurrentUser: Bool
    @Binding var reply: String?
    
    var body: some View {
        HStack(spacing: 6) {
            if !isCurrentUser {
                replyIcon
                replyContent
            } else {
                replyContent
                replyIcon
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
        )
        .onTapGesture { reply = messageId }
    }
    
    private var replyIcon: some View {
        Image(systemName: isCurrentUser ? "arrowshape.turn.up.left" : "arrowshape.turn.up.right")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var replyContent: some View {
        if let referencedMessage = webSocketService.data.first(where: { $0.messageId == messageId }) {
            if !isCurrentUser {
                Text(referencedMessage.author.currentname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(referencedMessage.content)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text(referencedMessage.content)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(referencedMessage.author.currentname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Referenced message unavailable")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct MessageContentView: View {
    let messageData: Message
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading) {
            if #available(iOS 19, *) {
                Group {
                    if isCurrentUser {
                        Text(messageData.content)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.white)
                    } else {
                        Markdown(messageData.content)
                            .markdownTheme(.basic)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                .glassEffect(.regular.tint(isCurrentUser ? .blue.opacity(0.6) : .init(uiColor: .darkGray).opacity(0.6)), in: .rect(cornerRadius: 16))
            } else {
                Group {
                    if isCurrentUser {
                        Text(messageData.content)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.white)
                    } else {
                        Markdown(messageData.content)
                            .markdownTheme(.basic)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isCurrentUser ? Color.blue : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrentUser ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
            }
        }
    }
}

// MARK: - Extensions
extension Color {
    init?(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}
