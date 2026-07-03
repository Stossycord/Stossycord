//
//  User.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct User: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let username: String
    let discriminator: String
    let avatar: String?
    let bot: Bool?
    let system: Bool?
    let mfaEnabled: Bool?
    let banner: String?
    let accentColor: Int?
    let locale: String?
    let verified: Bool?
    let email: String?
    let flags: Int?
    let premiumType: Int?
    let publicFlags: Int?
    let global_name: String?
    let bannerColor: String?
    let phone: String?
    let nsfwAllowed: Bool?
    let purchasedFlags: Int?
    let bio: String?
    let authenticatorTypes: [Int]?
    let premium: Bool?
    let mobile: Bool?
    let desktop: Bool?
    let pronouns: String?
    let premiumUsageFlags: Int?
    let ageVerificationStatus: Int?
    let clan: UserClan?
    let primaryGuild: UserClan?
    let premiumState: PremiumState?
    let avatarDecorationData: AvatarDecorationData?
    let displayNameStyles: DisplayNameStyles?
    // let collectibles: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case discriminator
        case avatar
        case bot
        case system
        case mfaEnabled = "mfa_enabled"
        case banner
        case accentColor = "accent_color"
        case locale
        case verified
        case email
        case flags
        case premiumType = "premium_type"
        case publicFlags = "public_flags"
        case global_name = "global_name"
        case bannerColor = "banner_color"
        case phone
        case nsfwAllowed = "nsfw_allowed"
        case purchasedFlags = "purchased_flags"
        case bio
        case authenticatorTypes = "authenticator_types"
        case premium
        case mobile
        case desktop
        case pronouns
        case premiumUsageFlags = "premium_usage_flags"
        case ageVerificationStatus = "age_verification_status"
        case clan
        case primaryGuild = "primary_guild"
        case premiumState = "premium_state"
        case avatarDecorationData = "avatar_decoration_data"
        case displayNameStyles = "display_name_styles"
        // case collectibles
    }
    
    
    public init(
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
        phone: String? = nil,
        nsfwAllowed: Bool? = nil,
        purchased_flags: Int? = nil,
        bio: String? = nil,
        authenticatorTypes: [Int]? = nil,
        premium: Bool? = nil,
        mobile: Bool? = nil,
        desktop: Bool? = nil,
        pronouns: String? = nil,
        premiumUsageFlags: Int? = nil,
        ageVerificationStatus: Int? = nil,
        clan: UserClan? = nil,
        primaryGuild: UserClan? = nil,
        premiumState: PremiumState? = nil,
        avatarDecorationData: AvatarDecorationData? = nil,
        displayNameStyles: DisplayNameStyles? = nil,
        // collectibles: [Any]? = nil
    ) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.avatar = avatar
        self.bot = bot
        self.system = system
        self.mfaEnabled = mfa_enabled
        self.banner = banner
        self.accentColor = accentColor
        self.locale = locale
        self.verified = verified
        self.email = email
        self.flags = flags
        self.premiumType = premiumType
        self.publicFlags = publicFlags
        self.global_name = global_name
        self.bannerColor = banner_color
        self.phone = phone
        self.nsfwAllowed = nsfwAllowed
        self.purchasedFlags = purchased_flags
        self.bio = bio
        self.authenticatorTypes = authenticatorTypes
        self.premium = premium
        self.mobile = mobile
        self.desktop = desktop
        self.pronouns = pronouns
        self.premiumUsageFlags = premiumUsageFlags
        self.ageVerificationStatus = ageVerificationStatus
        self.clan = clan
        self.primaryGuild = primaryGuild
        self.premiumState = premiumState
        self.avatarDecorationData = avatarDecorationData
        self.displayNameStyles = displayNameStyles
        // self.collectibles = collectibles
    }
    
    public init(from decoder: Decoder) throws {
         let container = try decoder.container(keyedBy: CodingKeys.self)
         
         self.id = try container.decode(String.self, forKey: .id)
         self.username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
         self.discriminator = try container.decodeIfPresent(String.self, forKey: .discriminator) ?? ""
         
         self.avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
         self.bot = try container.decodeIfPresent(Bool.self, forKey: .bot)
         self.system = try container.decodeIfPresent(Bool.self, forKey: .system)
         self.mfaEnabled = try container.decodeIfPresent(Bool.self, forKey: .mfaEnabled)
         self.banner = try container.decodeIfPresent(String.self, forKey: .banner)
         self.accentColor = try container.decodeIfPresent(Int.self, forKey: .accentColor)
         self.locale = try container.decodeIfPresent(String.self, forKey: .locale)
         self.verified = try container.decodeIfPresent(Bool.self, forKey: .verified)
         self.email = try container.decodeIfPresent(String.self, forKey: .email)
         self.flags = try container.decodeIfPresent(Int.self, forKey: .flags)
         self.premiumType = try container.decodeIfPresent(Int.self, forKey: .premiumType)
         self.publicFlags = try container.decodeIfPresent(Int.self, forKey: .publicFlags)
         self.global_name = try container.decodeIfPresent(String.self, forKey: .global_name)
         self.bannerColor = try container.decodeIfPresent(String.self, forKey: .bannerColor)
         self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
         self.nsfwAllowed = try container.decodeIfPresent(Bool.self, forKey: .nsfwAllowed)
         self.purchasedFlags = try container.decodeIfPresent(Int.self, forKey: .purchasedFlags)
         self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
         self.authenticatorTypes = try container.decodeIfPresent([Int].self, forKey: .authenticatorTypes)
         self.premium = try container.decodeIfPresent(Bool.self, forKey: .premium)
         self.mobile = try container.decodeIfPresent(Bool.self, forKey: .mobile)
         self.desktop = try container.decodeIfPresent(Bool.self, forKey: .desktop)
         self.pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
         self.premiumUsageFlags = try container.decodeIfPresent(Int.self, forKey: .premiumUsageFlags)
         self.ageVerificationStatus = try container.decodeIfPresent(Int.self, forKey: .ageVerificationStatus)
         self.clan = try container.decodeIfPresent(UserClan.self, forKey: .clan)
         self.primaryGuild = try container.decodeIfPresent(UserClan.self, forKey: .primaryGuild)
         self.premiumState = try container.decodeIfPresent(PremiumState.self, forKey: .premiumState)
         self.avatarDecorationData = try container.decodeIfPresent(AvatarDecorationData.self, forKey: .avatarDecorationData)
         self.displayNameStyles = try container.decodeIfPresent(DisplayNameStyles.self, forKey: .displayNameStyles)
         // self.collectibles = try container.decodeIfPresent([String].self, forKey: .collectibles)
     }
}

extension User {
    var hasNitro: Bool {
        if premium == true { return true }
        if let premiumType, premiumType > 0 { return true }
        if let premiumSubscriptionType = premiumState?.premiumSubscriptionType, premiumSubscriptionType > 0 { return true }
        return false
    }
}

struct UserClan: Codable, Equatable, Hashable {
    let badge: String?
    let identityEnabled: Bool?
    let identityGuildId: String?
    let tag: String?
    
    enum CodingKeys: String, CodingKey {
        case badge
        case identityEnabled = "identity_enabled"
        case identityGuildId = "identity_guild_id"
        case tag
    }
}

struct PremiumState: Codable, Equatable, Hashable {
    let premiumSource: Int?
    let premiumSubscriptionGroupRole: Int?
    let premiumSubscriptionType: Int?
    
    enum CodingKeys: String, CodingKey {
        case premiumSource = "premium_source"
        case premiumSubscriptionGroupRole = "premium_subscription_group_role"
        case premiumSubscriptionType = "premium_subscription_type"
    }
}

struct AvatarDecorationData: Codable, Equatable, Hashable {
    let asset: String
    let expiresAt: Int?
    let skuId: String
    
    enum CodingKeys: String, CodingKey {
        case asset
        case expiresAt = "expires_at"
        case skuId = "sku_id"
    }
}

struct DisplayNameStyles: Codable, Equatable, Hashable {
    let colors: [Int]?
    let effectId: Int?
    let fontId: Int?
    
    enum CodingKeys: String, CodingKey {
        case colors
        case effectId = "effect_id"
        case fontId = "font_id"
    }
}
