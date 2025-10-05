//
//  Channel.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

struct PermissionOverwrite: Codable, Hashable {
    let id: String
    let type: Int
    let allow: String
    let deny: String
}

struct ThreadMetadata: Codable, Hashable {
    let archived: Bool?
    let autoArchiveDuration: Int?
    let archiveTimestamp: String?
    let locked: Bool?
    let invitable: Bool?
    let createTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case archived
        case autoArchiveDuration = "auto_archive_duration"
        case archiveTimestamp = "archive_timestamp"
        case locked
        case invitable
        case createTimestamp = "create_timestamp"
    }
}

struct ForumReactionEmoji: Codable, Hashable {
    let emojiId: String?
    let emojiName: String?
    let emojiAnimated: Bool?

    enum CodingKeys: String, CodingKey {
        case emojiId = "emoji_id"
        case emojiName = "emoji_name"
        case emojiAnimated = "emoji_animated"
    }
}

struct Channel: Codable, Hashable, Identifiable {
    let id: String
    let guildId: String?
    let name: String?
    let type: Int
    let position: Int?
    let topic: String?
    let permissionOverwrites: [PermissionOverwrite]?
    let parentId: String?
    let ownerId: String?
    let lastMessageId: String?
    let rateLimitPerUser: Int?
    let bitrate: Int?
    let userLimit: Int?
    let rtcRegion: String?
    let threadMetadata: ThreadMetadata?
    let memberCount: Int?
    let messageCount: Int?
    let totalMessageSent: Int?
    let defaultAutoArchiveDuration: Int?
    let flags: Int?
    let appliedTags: [String]?
    let defaultReactionEmoji: ForumReactionEmoji?
    let defaultSortOrder: Int?
    let defaultForumLayout: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case guildId = "guild_id"
        case name
        case type
        case position
        case topic
        case permissionOverwrites = "permission_overwrites"
        case parentId = "parent_id"
        case ownerId = "owner_id"
        case lastMessageId = "last_message_id"
        case rateLimitPerUser = "rate_limit_per_user"
        case bitrate
        case userLimit = "user_limit"
        case rtcRegion = "rtc_region"
        case threadMetadata = "thread_metadata"
        case memberCount = "member_count"
        case messageCount = "message_count"
        case totalMessageSent = "total_message_sent"
        case defaultAutoArchiveDuration = "default_auto_archive_duration"
        case flags
        case appliedTags = "applied_tags"
        case defaultReactionEmoji = "default_reaction_emoji"
        case defaultSortOrder = "default_sort_order"
        case defaultForumLayout = "default_forum_layout"
    }
}

extension Channel {
    var displayName: String {
        name ?? "Unnamed Channel"
    }

    var isThread: Bool {
        type == 10 || type == 11 || type == 12
    }

    var isTextLike: Bool {
        [0, 5, 10, 11, 12, 15, 16].contains(type)
    }

    var isVoiceLike: Bool {
        type == 2 || type == 13
    }

    var isCategory: Bool {
        type == 4
    }

    var sortPosition: Int {
        position ?? Int.max
    }
}

struct Category: Codable, Hashable {
    let id: String
    let name: String?
    let type: Int
    let position: Int?
    let permissionOverwrites: [PermissionOverwrite]?
    var channels: [Channel]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case position
        case permissionOverwrites = "permission_overwrites"
        case channels
    }
}

