//
//  GuildMemberResponse.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//


import Foundation

struct GuildMember: Codable, Equatable {
    let user: User
    let roles: [String]
    let joinedAt: String
    let deaf: Bool
    let mute: Bool
    let premiumSince: String?
    let nick: String?
    let pending: Bool
    let communicationDisabledUntil: String?

    enum CodingKeys: String, CodingKey {
        case user
        case roles
        case joinedAt = "joined_at"
        case deaf
        case mute
        case premiumSince = "premium_since"
        case nick
        case pending
        case communicationDisabledUntil = "communication_disabled_until"
    }
}
