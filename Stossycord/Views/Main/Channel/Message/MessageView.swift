//
//  MessageView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation
import MarkdownUI

struct MessageView: View {
    // MARK: - Properties
    let messageData: Message
    @Binding var reply: String
    @StateObject var webSocketService: WebSocketService
    @State private var guildMember: GuildMember? = nil
    @State private var roleColor: Int = 0
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            avatarView(for: messageData.author)
            
            VStack(alignment: .leading, spacing: 4) {
                // Reply reference
                if let replyId = messageData.messageReference?.messageId {
                    replyIndicatorView(for: replyId)
                }
                
                // Author and edit info
                HStack(spacing: 4) {
                    Text(messageData.author.currentname)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(roleColor != 0 ? Color(hex: roleColor) : .primary)
                    
                    if messageData.editedtimestamp != nil {
                        Text("(edited)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Message content
                messageContentView(content: messageData.content)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .onAppear(perform: loadMemberInfo)
    }
    
    // MARK: - Component Views
    private func avatarView(for author: Author) -> some View {
        Group {
            if let avatar = author.avatarHash {
                AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).png")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 38, height: 38)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
            } else {
                AsyncImage(url: URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(7)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color(hex: 0x5865F2) ?? Color.blue))
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color(hex: 0x5865F2) ?? Color.blue)
                        .frame(width: 38, height: 38)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
            }
        }
    }
    
    private func replyIndicatorView(for messageId: String) -> some View {
        Group {
            if let referencedMessage = webSocketService.data.first(where: { $0.messageId == messageId }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Text("\(referencedMessage.author.currentname)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(referencedMessage.content)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
                .onTapGesture {
                    reply = messageId
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Text("Referenced message unavailable")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
        }
    }
    
    private func messageContentView(content: String) -> some View {
        Markdown(content)
            .markdownTheme(.basic)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
    
    // MARK: - Methods
    private func loadMemberInfo() {
        // Get member info
        self.guildMember = self.webSocketService.currentMembers.first(where: {
            $0.user.id == messageData.author.authorId
        })
        
        // Get role color
        if let roles = guildMember?.roles {
            if let role = roles.compactMap({ roleId in
                webSocketService.currentroles.first(where: { $0.id == roleId && $0.color != 0 })
            }).first {
                self.roleColor = role.color
            } else {
                self.roleColor = 0
            }
        }
    }
}

struct MessageSelfView: View {
    // MARK: - Properties
    let messageData: Message
    @Binding var reply: String
    @StateObject var webSocketService: WebSocketService
    @State private var guildMember: GuildMember? = nil
    @State private var roleColor: Int = 0
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Reply reference
                if let replyId = messageData.messageReference?.messageId {
                    replyIndicatorView(for: replyId)
                }
                
                // Author and edit info
                HStack(spacing: 4) {
                    if messageData.editedtimestamp != nil {
                        Text("(edited)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(messageData.author.currentname)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(roleColor != 0 ? Color(hex: roleColor) : .primary)
                }
                
                // Message content
                messageContentView(content: messageData.content)
            }
            
            // Avatar
            avatarView(for: messageData.author)
        }
        .padding(.vertical, 6)
        .onAppear(perform: loadMemberInfo)
    }
    
    // MARK: - Component Views
    private func avatarView(for author: Author) -> some View {
        Group {
            if let avatar = author.avatarHash {
                AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(author.authorId)/\(avatar).png")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 38, height: 38)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
            } else {
                AsyncImage(url: URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(7)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.blue))
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 38, height: 38)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
            }
        }
    }
    
    private func replyIndicatorView(for messageId: String) -> some View {
        Group {
            if let referencedMessage = webSocketService.data.first(where: { $0.messageId == messageId }) {
                HStack(spacing: 6) {
                    Text(referencedMessage.content)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text("\(referencedMessage.author.currentname)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
                .onTapGesture {
                    reply = messageId
                }
            } else {
                HStack(spacing: 6) {
                    Text("Referenced message unavailable")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
        }
    }
    
    private func messageContentView(content: String) -> some View {
        Text(LocalizedStringKey(content))
            .multilineTextAlignment(.trailing)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
    }
    
    // MARK: - Methods
    private func loadMemberInfo() {
        // Get member info
        self.guildMember = self.webSocketService.currentMembers.first(where: {
            $0.user.id == messageData.author.authorId
        })
        
        // Get role color
        if let roles = guildMember?.roles {
            if let role = roles.compactMap({ roleId in
                webSocketService.currentroles.first(where: { $0.id == roleId && $0.color != 0 })
            }).first {
                self.roleColor = role.color
            } else {
                self.roleColor = 0
            }
        }
    }
}

// MARK: - Color extension for hex support
extension Color {
    init?(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}
