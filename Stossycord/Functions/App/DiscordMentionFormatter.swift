//
//  DiscordMentionFormatter.swift
//  Stossycord
//
//  Created by Stossy11 on 2/7/2026.
//

import Foundation

enum DiscordMentionFormatter {
    enum Style {
        case markdown
        case plain
    }

    static let channelMentionScheme = "stossycord"
    static let channelMentionHost = "channel"

    static func format(
        message: Message,
        userSession: CurrentUserService,
        style: Style = .markdown,
        linkChannels: Bool = true
    ) -> String {
        format(
            content: message.content,
            guildId: message.guildId,
            authorUserId: message.author.id,
            authorDisplayName: message.author.currentname,
            mentions: message.mentions ?? [],
            userSession: userSession,
            style: style,
            linkChannels: linkChannels
        )
    }

    static func format(
        content: String,
        guildId: String?,
        authorUserId: String?,
        authorDisplayName: String?,
        mentions: [User] = [],
        userSession: CurrentUserService,
        style: Style = .markdown,
        linkChannels: Bool = true
    ) -> String {
        var text = content

        text = replacePattern(in: text, pattern: "<@!?(\\d+)>") { match, nsText in
            let userId = nsText.substring(with: match.range(at: 1))
            let displayName = resolveUserDisplayName(
                userId: userId,
                guildId: guildId,
                authorUserId: authorUserId,
                authorDisplayName: authorDisplayName,
                mentions: mentions,
                userSession: userSession
            )

            return mention("@\(displayName)", style: style)
        }

        text = replacePattern(in: text, pattern: "<#(\\d+)>") { match, nsText in
            let channelId = nsText.substring(with: match.range(at: 1))
            let name = userSession.resolveChannelById(channelId) ?? channelId
            guard linkChannels, style == .markdown else {
                return "#\(name)"
            }
            return "[#\(name)](\(channelMentionScheme)://\(channelMentionHost)/\(channelId))"
        }

        text = replacePattern(in: text, pattern: "<@&(\\d+)>") { match, nsText in
            let roleId = nsText.substring(with: match.range(at: 1))
            let roleName = guildId
                .flatMap { userSession.guildManager.roles[$0]?.first(where: { $0.id == roleId })?.name }
                ?? roleId
            return mention("@\(roleName)", style: style)
        }

        return text
    }

    private static func resolveUserDisplayName(
        userId: String,
        guildId: String?,
        authorUserId: String?,
        authorDisplayName: String?,
        mentions: [User],
        userSession: CurrentUserService
    ) -> String {
        if let guildId,
           let member = userSession.guildManager.members[guildId]?
            .first(where: { $0.user?.id == userId || $0.userId == userId }) {
            return member.nick ?? member.user?.global_name ?? member.user?.username ?? userId
        }

        if let mentionedUser = mentions.first(where: { $0.id == userId }) {
            return mentionedUser.global_name ?? mentionedUser.username
        }

        if let dmUser = userSession.dms
            .flatMap({ $0.recipients ?? [] })
            .first(where: { $0.id == userId }) {
            return dmUser.global_name ?? dmUser.username
        }

        if let currentUser = userSession.user, currentUser.id == userId {
            return currentUser.global_name ?? currentUser.username
        }

        if authorUserId == userId, let authorDisplayName {
            return authorDisplayName
        }

        return userId
    }

    private static func mention(_ value: String, style: Style) -> String {
        switch style {
        case .markdown:
            return "**\(escapeMarkdown(value))**"
        case .plain:
            return value
        }
    }

    private static func escapeMarkdown(_ value: String) -> String {
        var escaped = ""
        for character in value {
            if "\\`*_{}[]()#+-.!".contains(character) {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }

    private static func replacePattern(
        in text: String,
        pattern: String,
        replacement: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        let result = NSMutableString()
        var lastLocation = 0

        regex.enumerateMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text)
        ) { match, _, _ in
            guard let match else { return }
            result.append(nsText.substring(
                with: NSRange(
                    location: lastLocation,
                    length: match.range.location - lastLocation
                )
            ))
            result.append(replacement(match, nsText))
            lastLocation = match.range.location + match.range.length
        }

        result.append(nsText.substring(from: lastLocation))
        return result as String
    }
}
