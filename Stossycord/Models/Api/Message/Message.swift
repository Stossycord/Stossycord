//
//  Message.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct Message: Codable {
    let channelId: String
    var content: String
    let messageId: String
    var editedtimestamp: String?
    let timestamp: String?
    let type: Int?
    let guildId: String?
    let author: Author
    let messageReference: MessageReference?
    var attachments: [Attachment]?
    var embeds: [Embed]?
    var poll: Poll?
    let channelType: Int?
    
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
    }
}

struct Attachment: Codable {
    let url: String
    let id: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case id
    }
}

struct MessageReference: Codable {
    let messageId: String?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
}
