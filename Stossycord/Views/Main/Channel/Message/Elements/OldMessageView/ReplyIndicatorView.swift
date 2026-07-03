//
//  ReplyIndicatorView.swift
//  Stossycord
//
//  Created by Stossy11 on 16/1/2026.
//

import SwiftUI

struct ReplyIndicatorView: View {
    let messageId: String
    @StateObject var webSocketService: WebSocketService
    @EnvironmentObject var userSession: CurrentUserService
    let isCurrentUser: Bool
    @Binding var reply: String?
    
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = MessageBubbleStyle.imessage.rawValue
    
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
        if let referencedMessage = userSession.data.flatMap({ $0.messages }).first(where: { $0.messageId == messageId }) {
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
