//
//  User.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct User: Codable {
    let id: String
    let username: String
    let discriminator: String
    let avatar: String?
    let bot: Bool?
    let system: Bool?
    let mfa_enabled: Bool?
    let banner: String?
    let accentColor: Int?
    let locale: String?
    let verified: Bool?
    let email: String?
    let flags: Int?
    let premiumType: Int?
    let publicFlags: Int?
    let global_name: String?
    let banner_color: String?
    let clan: String?
    let phone: String?
    let nsfwAllowed: Bool?
    var purchased_flags: Int?
    let bio: String?
    let authenticatorTypes: [Int]?
    // let linked_users: [String]?
    
    init(
        id: String,
        username: String,
        discriminator: String,
        avatar: String,
        bot: Bool? = nil,
        system: Bool? = nil,
        mfa_enabled: Bool? = nil,
        banner: String? = nil,
        accentColor: Int? = nil,
        locale: String? = nil,
        verified: Bool? = nil,
        email: String? = nil,
        flags: Int? = nil,
        premiumType: Int? = nil,
        publicFlags: Int? = nil,
        global_name: String? = nil,
        banner_color: String? = nil,
        clan: String? = nil,
        phone: String? = nil,
        nsfwAllowed: Bool? = nil,
        purchased_flags: Int? = nil,
        bio: String? = nil,
        authenticatorTypes: [Int]? = nil,
        linked_users: [String]? = nil
    ) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.avatar = avatar
        self.bot = bot
        self.system = system
        self.mfa_enabled = mfa_enabled
        self.banner = banner
        self.accentColor = accentColor
        self.locale = locale
        self.verified = verified
        self.email = email
        self.flags = flags
        self.premiumType = premiumType
        self.publicFlags = publicFlags
        self.global_name = global_name
        self.banner_color = banner_color
        self.clan = clan
        self.phone = phone
        self.nsfwAllowed = nsfwAllowed
        self.purchased_flags = purchased_flags
        self.bio = bio
        self.authenticatorTypes = authenticatorTypes
        self.purchased_flags = purchased_flags
    }
}
