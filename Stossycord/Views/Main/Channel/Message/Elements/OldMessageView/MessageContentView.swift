//
//  MessageContentView.swift
//  Stossycord
//
//  Created by Stossy11 on 16/1/2026.
//

import SwiftUI
import MarkdownUI
import Foundation
import EmojiText

struct MessageContentView: View {
    let messageData: Message
    @State var updatedMessageContent: String?
    @EnvironmentObject var userSession: CurrentUserService
    
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = MessageBubbleStyle.imessage.rawValue
    let isCurrentUser: Bool
    
    var messageStyle: MessageBubbleStyle {
        MessageBubbleStyle(rawValue: messageStyleRawValue) ?? .imessage
    }
    
    var isOnlyEmojis: Bool {
        let contentWithoutWhitespace = messageData.content.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        
        if contentWithoutWhitespace.isEmpty { return false }
        
        let regex = try! NSRegularExpression(pattern: #"<(a?):(\w+):(\d+)>"#, options: [])
        let range = NSRange(contentWithoutWhitespace.startIndex..., in: contentWithoutWhitespace)
        let contentWithoutCustomEmojis = regex.stringByReplacingMatches(in: contentWithoutWhitespace, options: [], range: range, withTemplate: "")
        
        return contentWithoutCustomEmojis.isEmpty || contentWithoutCustomEmojis.allSatisfy { $0.isEmoji }
    }
    
    var emojis: [RemoteEmoji] {
        var emojis: [RemoteEmoji] = []
        
        let regex = try! NSRegularExpression(pattern: #"<(a?):(\w+):(\d+)>"#, options: [])
        let matches = regex.matches(in: messageData.content, options: [], range: NSRange(messageData.content.startIndex..., in: messageData.content))
        
        for match in matches {
            guard match.numberOfRanges == 4,
                  let animatedRange = Range(match.range(at: 1), in: messageData.content),
                  let nameRange = Range(match.range(at: 2), in: messageData.content),
                  let idRange = Range(match.range(at: 3), in: messageData.content) else {
                continue
            }
            
            let animated = !messageData.content[animatedRange].isEmpty
            let id = String(messageData.content[idRange])
            let name = String(messageData.content[nameRange])
            let shortcode = ":\(name):"
            
            let ext = animated ? "gif" : "png"
            let url = "https://cdn.discordapp.com/emojis/\(id).\(ext)"
            
            emojis.append(RemoteEmoji(shortcode: shortcode, url: URL(string: url + "?size=96")!))
        }
        
        return emojis
    }
    
    var body: some View {
        Group {
            if isOnlyEmojis {
                HStack {
                    ForEach(emojis.compactMap(\.url).indices, id: \.self) { cool in
                        let emoji = emojis.compactMap(\.url)[cool]
                        
                        EmojiMessageView(url: emoji)
                    }
                }
                .frame(alignment: isCurrentUser ? .trailing : .leading)
            } else if messageStyle == .default {
                discordMessage
            } else {
                imessageMessage
            }
        }
        .task {
            if let embeds = messageData.embeds, !embeds.isEmpty, embeds.count == 1 {
                if messageData.content == embeds[0].url {
                    updatedMessageContent = ""
                    return
                } else if let embedURL = embeds[0].url, isExactMarkdownLink(messageData.content, url: embedURL) {
                    updatedMessageContent = ""
                    return
                }
            }
            
            await replaceMentions()
        }
    }
    
    
    @ViewBuilder
    var discordMessage: some View {
        EmojiText(verbatim: contentForEmojiText(updatedMessageContent ?? messageData.content), emojis: emojis, shouldCheckForColon: false)
            .animated()
            .multilineTextAlignment(.leading)
            .foregroundColor(.white)
            .padding(12)
    }
    
    
    @ViewBuilder
    var imessageMessage: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading) {
            if updatedMessageContent?.isEmpty == true {
                EmptyView()
            } else {
                if #available(iOS 19, *) {
                    Group {
                        if isCurrentUser {
                            EmojiText(verbatim: contentForEmojiText(updatedMessageContent ?? messageData.content), emojis: emojis, shouldCheckForColon: false)
                                .animated()
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.white)
                        } else {
                            EmojiText(verbatim: contentForEmojiText(updatedMessageContent ?? messageData.content), emojis: emojis, shouldCheckForColon: false)
                                .animated()
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(12)
                    .glassEffect(.regular.tint(isCurrentUser ? .blue.opacity(0.6) : .init(uiColor: .darkGray).opacity(0.6)), in: .rect(cornerRadius: 16))
                } else {
                    Group {
                        if isCurrentUser {
                            EmojiText(verbatim: contentForEmojiText(updatedMessageContent ?? messageData.content), emojis: emojis, shouldCheckForColon: false)
                                .animated()
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.white)
                        } else {
                            EmojiText(verbatim: contentForEmojiText(updatedMessageContent ?? messageData.content), emojis: emojis, shouldCheckForColon: false)
                                .animated()
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
    
    func replaceMentions() async {
        let text = DiscordMentionFormatter.format(
            message: messageData,
            userSession: userSession,
            style: .markdown,
            linkChannels: false
        )
        
        await MainActor.run {
            self.updatedMessageContent = text
        }
    }
    
    private func contentForEmojiText(_ content: String) -> String {
        let regex = try! NSRegularExpression(pattern: #"<a?:([A-Za-z0-9_]+):\d+>"#)
        let nsContent = content as NSString
        let result = NSMutableString()
        var lastLocation = 0
        
        regex.enumerateMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content)) { match, _, _ in
            guard let match else { return }
            result.append(nsContent.substring(with: NSRange(location: lastLocation, length: match.range.location - lastLocation)))
            result.append(":\(nsContent.substring(with: match.range(at: 1))):")
            lastLocation = match.range.location + match.range.length
        }
        
        result.append(nsContent.substring(from: lastLocation))
        return result as String
    }
    
    func isExactMarkdownLink(_ text: String, url: String) -> Bool {
        let escapedURL = NSRegularExpression.escapedPattern(for: url)
        
        let pattern = #"^\[[^\]]*\]\("# + escapedURL + #"\)$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        return !matches.isEmpty
    }
}
