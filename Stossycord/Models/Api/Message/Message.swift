//
//  Message.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct Message: Codable, Equatable, Identifiable {
    var id: String { messageId }
    let channelId: String
    var content: String
    let messageId: String
    var editedtimestamp: String?
    let timestamp: String?
    let type: Int?
    var guildId: String?
    let author: Author
    let messageReference: MessageReference?
    var attachments: [Attachment]?
    var embeds: [Embed]?
    var poll: Poll?
    let channelType: Int?
    var reactions: [Reaction]?
    let mentioned: Bool?
    let mentionEveryone: Bool?
    let mentions: [User]?
    let mentionRoles: [String]?
    
    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case content
        case messageId = "id"
        case timestamp
        case type
        case guildId = "guild_id"
        case author
        case editedtimestamp = "edited_timestamp"
        case messageReference = "message_reference"
        case attachments
        case embeds
        case poll
        case channelType = "channel_type"
        case reactions
        case mentioned
        case mentionEveryone = "mention_everyone"
        case mentions
        case mentionRoles = "mention_roles"
    }
}

struct Attachment: Codable, Equatable {
    let url: String
    let id: String
    let width: Int?
    let height: Int?
    let size: Int?
    let proxyUrl: String?
    let filename: String?
    let contentType: String?
    let spoiler: Bool?
    let placeholder: String?
    let placeholderVersion: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case id
        case width
        case height
        case size
        case proxyUrl = "proxy_url"
        case filename
        case contentType = "content_type"
        case spoiler
        case placeholder
        case placeholderVersion = "placeholder_version"
    }
}

struct MessageReference: Codable, Equatable {
    let messageId: String?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
}
