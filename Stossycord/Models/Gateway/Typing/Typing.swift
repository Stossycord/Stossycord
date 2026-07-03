//
//  Typing.swift
//  Stossycord
//
//  Created by Stossy11 on 17/1/2026.
//

import Foundation

struct Typing: Codable {
    var user_id: String
    var channel_id: String
    var guild_id: String?
    var member: GuildMember?
    var timestamp: Int
}

