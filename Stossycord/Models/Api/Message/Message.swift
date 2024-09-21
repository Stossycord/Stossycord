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
    let author: Author
    let messageReference: MessageReference?
    let attachments: [Attachment]?
    
    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case content
        case messageId = "id"
        case author
        case messageReference = "message_reference"
        case attachments
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
