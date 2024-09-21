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
                        .background(Circle().fill(Color(hex: "#5865F2") ?? Color.blue))
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
                Text(messageData.author.currentname)
                    .bold()
                    .foregroundColor(.primary)
                
                // Message bubble
                Text(LocalizedStringKey(messageData.content))
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 16))
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
            }
            Spacer()
        }
        .padding(10)
    }
}

struct MessageSelfView: View {
    let messageData: Message
    @Binding var reply: String
    @StateObject var webSocketService: WebSocketService
    
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
                // Author display name (if needed)
                Text(messageData.author.currentname)
                    .bold()
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                
                // Message bubble
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
    }
}
