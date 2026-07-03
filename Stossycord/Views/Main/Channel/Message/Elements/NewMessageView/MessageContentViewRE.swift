//
//  MessageContentViewRE.swift
//  Stossycord
//
//  Created by Stossy11 on 16/1/2026.
//

import SwiftUI
import EmojiText

struct MessageContentViewRE: View {
    let messageData: Message
    let isCurrentUser: Bool
    let style: MessageBubbleStyle
    let configuration: MessageBubbleVisualConfiguration
    let editedTimestamp: String?
    let maxWidth: CGFloat?
    
    var onChannelMentionTapped: ((String) -> Void)? = nil
    
    private var isEdited: Bool { editedTimestamp != nil }
    private var currentSide: MessageBubbleVisualConfiguration.Side {
        isCurrentUser ? configuration.currentUser : configuration.otherUser
    }
    private var textAlignment: TextAlignment { isCurrentUser ? .trailing : .leading }
    private var lineSpacing: CGFloat { 2 }
    
    private var messageAttributedString: AttributedString {
        (try? AttributedString(markdown: updatedMessageContent ?? messageData.content, options: MessageContentViewRE.markdownOptions))
        ?? AttributedString(updatedMessageContent ?? messageData.content)
    }
    
    private static let markdownOptions = AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: true, interpretedSyntax: .full)
    
    @State var updatedMessageContent: String?
    @EnvironmentObject var userSession: CurrentUserService
    
    var isOnlyEmojis: Bool {
        let contentWithoutWhitespace = messageData.content.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        
        if contentWithoutWhitespace.isEmpty { return false }
        
        let regex = try! NSRegularExpression(pattern: #"<(a?):(\w+):(\d+)>"#, options: [])
        let range = NSRange(contentWithoutWhitespace.startIndex..., in: contentWithoutWhitespace)
        let contentWithoutCustomEmojis = regex.stringByReplacingMatches(in: contentWithoutWhitespace, options: [], range: range, withTemplate: "")
        
        return contentWithoutCustomEmojis.isEmpty || contentWithoutCustomEmojis.allSatisfy { $0.isEmoji }
    }
    
    var isOnlyNativeEmojis: Bool {
        isOnlyEmojis && emojis.isEmpty
    }
    
    var nativeEmojis: [Character] {
        messageData.content
            .filter { $0.isEmoji }
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
        bubbleContainer {
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                messageContent
                    .lineSpacing(lineSpacing)
                
                if style != .default && isEdited {
                    Text("(edited)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                }
            }
        }
        .onAppear() {
            print(isOnlyEmojis)
        }
        .frame(maxWidth: maxWidth, alignment: isCurrentUser ? .trailing : .leading)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == DiscordMentionFormatter.channelMentionScheme,
                  url.host == DiscordMentionFormatter.channelMentionHost,
                  let channelId = url.pathComponents.dropFirst().first
            else { return .systemAction }
            onChannelMentionTapped?(channelId)
            return .handled
        })
        .onChange(of: messageData) { _ in
            Task {
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
    private var messageContent: some View {
        EmojiText(verbatim: contentForEmojiText(updatedMessageContent ?? messageData.content), emojis: emojis, shouldCheckForColon: false)
            .animated()
            .multilineTextAlignment(textAlignment)
            .font(.system(size: 14))
    }
    
    @ViewBuilder
    private var nativeEmojiContent: some View {
        HStack(spacing: 2) {
            ForEach(nativeEmojis.indices, id: \.self) { index in
                Text(String(nativeEmojis[index]))
                    .font(.system(size: 48))
            }
        }
    }
    
    @ViewBuilder
    private func bubbleContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let side = currentSide
        let padded = content()
            .padding(configuration.padding.edgeInsets)
        
        if isOnlyEmojis {
            if isOnlyNativeEmojis {
                if #available(iOS 19.0, *) {
                    nativeEmojiContent
                        .padding(configuration.padding.edgeInsets)
                        .glassEffect(
                            .regular.tint(side.background.opacity(0.6)),
                            in: .rect(cornerRadius: configuration.cornerRadius)
                        )
                        .overlay(strokeOverlay(for: side))
                } else {
                    nativeEmojiContent
                        .padding(configuration.padding.edgeInsets)
                        .background(
                            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                                .fill(side.background)
                        )
                        .overlay(strokeOverlay(for: side))
                }
            } else {
                if #available(iOS 19.0, *) {
                    HStack {
                        ForEach(emojis.compactMap(\.url).indices, id: \.self) { cool in
                            let emoji = emojis.compactMap(\.url)[cool]
                            
                            EmojiMessageView(url: emoji)
                        }
                    }
                    .padding(configuration.padding.edgeInsets)
                    .glassEffect(
                        .regular.tint(side.background.opacity(0.6)),
                        in: .rect(cornerRadius: configuration.cornerRadius)
                    )
                    .overlay(strokeOverlay(for: side))
                } else {
                    HStack {
                        ForEach(emojis.compactMap(\.url).indices, id: \.self) { cool in
                            let emoji = emojis.compactMap(\.url)[cool]
                            
                            EmojiMessageView(url: emoji)
                        }
                    }
                    .padding(configuration.padding.edgeInsets)
                    .background(
                        RoundedRectangle(cornerRadius: configuration.cornerRadius)
                            .fill(side.background)
                    )
                    .overlay(strokeOverlay(for: side))
                }
            }
        } else {
#if os(iOS)
            if #available(iOS 19, *), configuration.glassEffect {
                padded
                    .glassEffect(
                        .regular.tint(side.background.opacity(0.6)),
                        in: .rect(cornerRadius: configuration.cornerRadius)
                    )
                    .overlay(strokeOverlay(for: side))
            } else {
                padded
                    .background(
                        RoundedRectangle(cornerRadius: configuration.cornerRadius)
                            .fill(side.background)
                    )
                    .overlay(strokeOverlay(for: side))
            }
#else
            padded
                .background(
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .fill(side.background)
                )
                .overlay(strokeOverlay(for: side))
#endif
        }
    }
    
    @ViewBuilder
    private func strokeOverlay(for side: MessageBubbleVisualConfiguration.Side) -> some View {
        if configuration.strokeWidth > 0 {
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(side.stroke ?? Color.clear, lineWidth: configuration.strokeWidth)
        }
    }
    
    func replaceMentions() async {
        let text = DiscordMentionFormatter.format(
            message: messageData,
            userSession: userSession,
            style: .markdown
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

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.properties.isEmojiPresentation || unicodeScalars.count > 1)
    }
}
