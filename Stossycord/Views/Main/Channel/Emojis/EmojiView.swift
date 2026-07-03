//
//  EmojiView.swift
//  Stossycord
//
//  Created by Stossy11 on 17/1/2026.
//

import SwiftUI
#if canImport(Giffy)
import Giffy
#endif

struct EmojiView: View {
    let guild: Guild?
    let onTap: (Emoji) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userService: CurrentUserService
    @AppStorage(DesignSettingsKeys.allowFakeNitroEmojis) private var allowFakeNitroEmojis: Bool = true
    @State private var searchText = ""
    let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]
    var otherGuilds: [Guild] {
        guard userService.hasNitro || allowFakeNitroEmojis else { return [] }
        
        return userService.Guilds.filter {
            $0.id != guild?.id && ($0.emojis?.isEmpty == false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if let guild {
                        emojiSection(title: guild.name, emojis: filteredEmojis(for: guild.id))
                    }
                    
                    ForEach(otherGuilds) { guild in
                        let emojis = filteredEmojis(for: guild.id)
                        if !emojis.isEmpty {
                            emojiSection(title: guild.name, emojis: emojis)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search emojis", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear emoji search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private func filteredEmojis(for guildId: String) -> [Emoji] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let emojis = Array(userService.guildManager.emojis[guildId, default: []])
            .filter { emoji in
                isEmojiAllowed(emoji, from: guildId)
            }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        
        guard !query.isEmpty else {
            return emojis
        }
        
        return emojis.filter { emoji in
            let name = emoji.name ?? ""
            let shortcode = emoji.discordShortcode ?? ""
            
            return name.localizedCaseInsensitiveContains(query) ||
            shortcode.localizedCaseInsensitiveContains(query) ||
            name.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(query)
        }
    }
    
    private func isEmojiAllowed(_ emoji: Emoji, from guildId: String) -> Bool {
        guard !userService.hasNitro else { return true }
        
        guard allowFakeNitroEmojis else {
            return guildId == guild?.id && emoji.animated != true
        }
        
        return true
    }
    
    private func emojiSection(title: String, emojis: [Emoji]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(emojis) { emoji in
                    EmojiImageView(emoji: emoji, onProfileTap: { dismiss(); onTap(emoji) })
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

struct EmojiImageView: View {
    let emoji: Emoji
    let onProfileTap: (() -> Void)?
    
    var body: some View {
        Button {
            onProfileTap?()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var content: some View {
        if let url = avatarURL {
            if emoji.animated == true {
#if os(iOS)
                AsyncGiffy(url: url) { phase in
                    switch phase {
                    case .loading:
                        placeholder
                    case .error:
                        placeholder
                    case .success(let giffy):
                        giffy
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 25, height: 25)
                    }
                }
#else
                AnimatedWebImage(url: url)
                    .frame(width: 25, height: 25)
                    .clipShape(Circle())
#endif
            } else {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 25, height: 25)
                } placeholder: {
                    placeholder
                }
                .frame(width: 25, height: 25)
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                ProgressView()
                    .scaleEffect(0.6)
            )
            .frame(width: 25, height: 25)
    }
    
    private var avatarURL: URL? {
        guard let id = emoji.id else {
            return URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")
        }
        
        if emoji.animated == true {
            return URL(string: "https://cdn.discordapp.com/emojis/\(id).gif?size=96&animated=true")
        } else {
            return URL(string: "https://cdn.discordapp.com/emojis/\(id).png?size=96")
        }
    }
}
