//
//  MessageView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation

struct MessageView: View {
    let messageData: Message
    @Binding var reply: String
    @StateObject var webSocketService: WebSocketService
    @State var guildMember: GuildMember? = nil
    @State var roleColor: Int = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            
            // Avatar
            if let avatar = messageData.author.avatarHash {
                AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(messageData.author.authorId)/\(avatar).png")) { image in
                    image.resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                }
            } else {
                AsyncImage(url: URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(7)
                        .background(Circle().fill(Color(hex: 0x5865F2) ?? Color.blue))
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                
                // Author name and reply indicator
                if let beansman = messageData.messageReference?.messageId {
                    if let matchingMessage = webSocketService.data.first(where: { $0.messageId == beansman }) {
                        HStack {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 8)) // Smaller arrow size
                                .foregroundColor(.gray)
                            Text("\(matchingMessage.author.currentname): \(matchingMessage.content)")
                                .font(.system(size: 10)) // Same size for the text
                                .foregroundColor(.gray)
                        }
                        .onTapGesture {
                            reply = matchingMessage.messageId
                        }
                    } else {
                        HStack {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 8)) // Smaller arrow size
                                .foregroundColor(.gray)
                            Text("Unable to get reply")
                                .font(.system(size: 10)) // Same size for the text
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Author display name
                
                if roleColor != 0  {
                    Text(messageData.author.currentname)
                        .bold()
                        .foregroundColor(.init(hex: roleColor))
                } else {
                    Text(messageData.author.currentname)
                        .bold()
                        .foregroundColor(.primary)
                }
                
                // Message bubble
                Text(LocalizedStringKey(messageData.content))
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 16))
                    .padding(10)
                #if os(macOS)
                    .background(Color(.systemGray))
                #else
                    .background(Color(.systemGray2))
                #endif
                    .cornerRadius(15)
#if os(macOS)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color(.systemGray), lineWidth: 1)
                    )
#else
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
#endif
                
            }
            Spacer()
        }
        .padding(10)
        .onAppear() {
            self.guildMember = self.webSocketService.currentMembers.first(where: { $0.user.id == messageData.author.authorId})
            
            
            if let roles = guildMember?.roles {
                if let role = roles.compactMap({ roleId in
                    webSocketService.currentroles.first(where: { $0.id == roleId && $0.color != 0 })
                }).first {
                    self.roleColor = role.color
                    print(roleColor)
                } else {
                    self.roleColor = 0
                }
            } else {
                print("No roles available.")
            }
        }
    }
}

struct MessageSelfView: View {
    let messageData: Message
    @Binding var reply: String
    @StateObject var webSocketService: WebSocketService
    @State var guildMember: GuildMember? = nil
    @State var roleColor: Int = 0
    
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                // Optional reply indicator
                if let beansman = messageData.messageReference?.messageId {
                    if let matchingMessage = webSocketService.data.first(where: { $0.messageId == beansman }) {
                        HStack {
                            Text("\(matchingMessage.author.currentname): \(matchingMessage.content)")
                                .font(.system(size: 10)) // Same size for the text
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "arrow.turn.up.left")
                                .font(.system(size: 8)) // Smaller arrow size
                                .foregroundColor(.gray)
                        }
                        .onTapGesture {
                            reply = matchingMessage.messageId
                        }
                    } else {
                        HStack {
                            Text("Unable to get reply")
                                .font(.system(size: 10)) // Same size for the text
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "arrow.turn.up.left")
                                .font(.system(size: 8)) // Smaller arrow size
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                
                if roleColor != 0  {
                    Text(messageData.author.currentname)
                        .bold()
                        .foregroundColor(Color(hex: roleColor))
                } else {
                    Text(messageData.author.currentname)
                        .bold()
                        .foregroundColor(.primary)
                }
                
               
                Text(LocalizedStringKey(messageData.content))
                    .multilineTextAlignment(.trailing)
                    .accentColor(.white)
                    .font(.system(size: 16))
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.blue, lineWidth: 1)
                    )
            }
            
            // Avatar on the right for your messages
            if let avatar = messageData.author.avatarHash {
                AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(messageData.author.authorId)/\(avatar).png")) { image in
                    image.resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                }
            } else {
                AsyncImage(url: URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(7)
                        .background(Circle().fill(Color.blue))
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                }
            }
        }
        .padding(10)
        .onAppear() {
            self.guildMember = self.webSocketService.currentMembers.first(where: { $0.user.id == messageData.author.authorId})
            
            
            if let roles = guildMember?.roles {
                // Find the first role with a color different from 0
                if let role = roles.compactMap({ roleId in
                    webSocketService.currentroles.first(where: { $0.id == roleId && $0.color != 0 })
                }).first {
                    self.roleColor = role.color
                    print(roleColor)
                } else {
                    // If no role with a color other than 0 is found
                    self.roleColor = 0
                    print("No role with color other than 0 found.")
                }
            } else {
                print("No roles available.")
            }

        }
    }
}
