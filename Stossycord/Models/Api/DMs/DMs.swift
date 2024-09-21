//
//  DMs.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import Foundation

struct Recipient: Codable {
    let globalName: String?
    let username: String
    let id: String
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case globalName = "global_name"
        case username
        case id
        case avatar
    }
}

struct DMs: Codable {
    let id: String
    let type: Int
    let last_message_id: String?
    let recipients: [User]?
    
    var position: Int {
        return Int(last_message_id ?? "") ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case last_message_id
        case recipients
    }
}
