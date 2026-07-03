//
//  EmbedCardView.swift
//  Stossycord
//
//  Created by Stossy11 on 2/7/2026.
//

import SwiftUI
import AVKit
import Foundation
import MarkdownUI
import AVFoundation
#if canImport(Giffy)
import Giffy
#endif

struct EmbedCardView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    let embed: Embed
    let isCurrentUser: Bool

    private var accentColor: Color {
        if let color = embed.color, let resolved = Color(hex: color) {
            return resolved
        }
        return Color.accentColor
    }

    private var displayTimestamp: String? {
        guard let timestamp = embed.timestamp else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return nil
    }

    private var isStandaloneEmojiImageEmbed: Bool {
        guard embed.type == "image",
              embed.title == nil,
              embed.description == nil,
              embed.timestamp == nil,
              embed.color == nil,
              embed.footer == nil,
              embed.thumbnail == nil,
              embed.video == nil,
              embed.provider == nil,
              embed.author == nil,
              embed.fields?.isEmpty != false,
              embed.image?.width == 48,
              embed.image?.height == 48
        else {
            return false
        }

        return emojiURLCandidates.contains { urlString in
            guard let url = URL(string: urlString) else { return false }
            return isDiscordEmojiURL(url)
        }
    }

    private var emojiURLCandidates: [String] {
        [embed.image?.url, embed.url, embed.image?.proxyURL]
            .compactMap { $0 }
    }

    var body: some View {
        if isStandaloneEmojiImageEmbed, let url = emojiURLCandidates.compactMap(URL.init(string:)).first {
            standaloneEmoji(url: url)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
                fields
                media
                footer
            }
            .padding(14)
            .background(background)
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(isCurrentUser ? 0.25 : 0.15), Color(.secondarySystemBackground).opacity(isCurrentUser ? 0.8 : 1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accentColor.opacity(0.25), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var header: some View {
        if let author = embed.author, author.name != nil || author.iconURL != nil {
            HStack(alignment: .center, spacing: 8) {
                if let icon = author.iconURL, let url = URL(string: icon) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                if let name = author.name {
                    if let link = author.url, let url = URL(string: link) {
                        if #available(iOS 16.0, *) {
                            Link(name, destination: url)
                                .font(.subheadline.weight(.semibold))
                                .underline()
                                .foregroundStyle(accentColor)
                        } else {
                            Link(name, destination: url)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accentColor)
                        }
                    } else {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = embed.title {
                if let link = embed.url, let url = URL(string: link) {
                    Link(title, destination: url)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                }
            }
            if let description = embed.description, !description.isEmpty {
                Markdown(description)
                    .markdownTheme(.basic)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        if let fields = embed.fields, !fields.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                let inlineFields = fields.filter { $0.isInline == true }
                let blockFields = fields.filter { $0.isInline != true }
                if !inlineFields.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(inlineFields, id: \.self) { field in
                            fieldView(field)
                        }
                    }
                }
                if !blockFields.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(blockFields, id: \.self) { field in
                            fieldView(field)
                        }
                    }
                }
            }
        }
    }

    private func fieldView(_ field: EmbedField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = field.name {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
            if let value = field.value {
                Markdown(value)
                    .markdownTheme(.basic)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var media: some View {
        if let videoProxy = embed.video?.proxyURL, let url = URL(string: videoProxy) {
            let displaySize = embedMediaSize(width: embed.video?.width, height: embed.video?.height)
            PlayerViewController(url: url)
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            let thumbnailURLString = embed.thumbnail?.proxyURL ?? embed.thumbnail?.url
            let imageURLString = embed.image?.proxyURL ?? embed.image?.url

            if let urlString = thumbnailURLString, let url = URL(string: urlString) {
                embedImage(url: url, width: embed.thumbnail?.width, height: embed.thumbnail?.height)
            }

            if let urlString = imageURLString, let url = URL(string: urlString) {
                embedImage(url: url, width: embed.image?.width, height: embed.image?.height)
            }
        }
    }

    @ViewBuilder
    private func embedImage(url: URL, width: Int?, height: Int?) -> some View {
        let ext = url.pathExtension(strippingQuery: true).lowercased()
        let displaySize = isDiscordEmojiURL(url) ? CGSize(width: 48, height: 48) : embedMediaSize(width: width, height: height)

        if ext == "mp4" {
            PlayerViewController(url: url)
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if ext == "gif" || ext == "webp" {
            AnimatedImageView(url: url)
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(width: displaySize.width, height: displaySize.height)
        }
    }

    @ViewBuilder
    private func standaloneEmoji(url: URL) -> some View {
        if url.pathExtension(strippingQuery: true).lowercased() == "gif" {
            AnimatedImageView(url: url)
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
        } else {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 48, height: 48)
        }
    }

    private func embedMediaSize(width: Int?, height: Int?) -> CGSize {
        let maxWidth: CGFloat = 350
        let maxHeight: CGFloat = 300

        guard let width,
              let height,
              width > 0,
              height > 0 else {
            return CGSize(width: maxWidth, height: min(maxHeight, CGFloat(height ?? 240)))
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

    private func isDiscordEmojiURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isDiscordMediaHost = host == "cdn.discordapp.com"
            || host == "media.discordapp.net"
            || host == "media.discordapp.com"
            || (host.hasPrefix("images-ext-") && host.hasSuffix(".discordapp.net"))

        if isDiscordMediaHost && url.path.lowercased().contains("/emojis/") {
            return true
        }

        if isDiscordMediaHost,
           url.absoluteString.lowercased().contains("cdn.discordapp.com/emojis/") {
            return true
        }

        guard isDiscordMediaHost,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let proxiedURL = components.queryItems?.first(where: { $0.name == "url" })?.value?.lowercased()
        else {
            return false
        }

        return proxiedURL.contains("cdn.discordapp.com/emojis/")
            || proxiedURL.contains("cdn.discordapp.com%2femojis%2f")
    }

    @ViewBuilder
    private var footer: some View {
        if let footer = embed.footer?.text, let timestamp = displayTimestamp {
            Text("\(footer) • \(timestamp)")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        } else if let footer = embed.footer?.text {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        } else if let timestamp = displayTimestamp {
            Text(timestamp)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        } else if let provider = embed.provider?.name {
            Text(provider)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
    }
}

private extension URL {
    func pathExtension(strippingQuery: Bool) -> String {
        guard strippingQuery else { return pathExtension }
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url?.pathExtension ?? pathExtension
    }
}

struct PlayerViewController: UIViewControllerRepresentable {
    let url: URL
    let isMuted: Bool = true
    let loops: Bool = true
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        player.isMuted = isMuted
        
        if loops {
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.loop(_:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
        }
        
        context.coordinator.player = player
        context.coordinator.item = item
        
        player.play()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    }
    
    static func dismantleUIViewController(
        _ uiViewController: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        coordinator.player?.pause()
        coordinator.player = nil
        coordinator.item = nil
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        weak var player: AVPlayer?
        weak var item: AVPlayerItem?
        
        @objc func loop(_ notification: Notification) {
            guard
                let finishedItem = notification.object as? AVPlayerItem,
                finishedItem === item,
                let player
            else { return }
            
            player.seek(to: .zero)
            player.play()
        }
    }
}
