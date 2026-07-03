//
//  GuildMemberResponse.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//


import Foundation

struct GuildMember: Codable, Equatable, Hashable, Identifiable {
    var id: String { userId ?? user?.id ?? "" }
    
    let user: User?
    let userId: String?
    let roles: [String]
    let joinedAt: String
    let deaf: Bool
    let mute: Bool
    let premiumSince: String?
    let nick: String?
    let pending: Bool
    let communicationDisabledUntil: String?
    let avatar: String?
    let banner: String?
    let flags: Int?

    enum CodingKeys: String, CodingKey {
        case user
        case userId = "user_id"
        case roles
        case joinedAt = "joined_at"
        case deaf
        case mute
        case premiumSince = "premium_since"
        case nick
        case pending
        case communicationDisabledUntil = "communication_disabled_until"
        case avatar
        case banner
        case flags
    }
    
    init(
        user: User,
        roles: [String],
        joinedAt: String,
        deaf: Bool,
        mute: Bool,
        premiumSince: String? = nil,
        nick: String? = nil,
        pending: Bool,
        communicationDisabledUntil: String? = nil,
        avatar: String? = nil,
        banner: String? = nil,
        flags: Int? = nil
    ) {
        self.user = user
        self.userId = user.id
        self.roles = roles
        self.joinedAt = joinedAt
        self.deaf = deaf
        self.mute = mute
        self.premiumSince = premiumSince
        self.nick = nick
        self.pending = pending
        self.communicationDisabledUntil = communicationDisabledUntil
        self.avatar = avatar
        self.banner = banner
        self.flags = flags
    }
    
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        user = try container.decodeIfPresent(User.self, forKey: .user)
        
        if let userIdInt = try? container.decodeIfPresent(Int.self, forKey: .userId) {
            userId = String(userIdInt)
        } else {
            userId = try container.decodeIfPresent(String.self, forKey: .userId)
        }
        
        roles = try container.decode([String].self, forKey: .roles)
        joinedAt = try container.decode(String.self, forKey: .joinedAt)
        
        if let deafInt = try? container.decode(Int.self, forKey: .deaf) {
            deaf = deafInt != 0
        } else {
            deaf = try container.decode(Bool.self, forKey: .deaf)
        }
        
        if let muteInt = try? container.decode(Int.self, forKey: .mute) {
            mute = muteInt != 0
        } else {
            mute = try container.decode(Bool.self, forKey: .mute)
        }
        
        if let pendingInt = try? container.decode(Int.self, forKey: .pending) {
            pending = pendingInt != 0
        } else {
            pending = try container.decode(Bool.self, forKey: .pending)
        }
        
        premiumSince = try container.decodeIfPresent(String.self, forKey: .premiumSince)
        nick = try container.decodeIfPresent(String.self, forKey: .nick)
        communicationDisabledUntil = try container.decodeIfPresent(String.self, forKey: .communicationDisabledUntil)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        banner = try container.decodeIfPresent(String.self, forKey: .banner)
        flags = try container.decodeIfPresent(Int.self, forKey: .flags)
    }
}
