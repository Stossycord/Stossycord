import Foundation

struct UserProfile: Codable {
    let user: User
    let connectedAccounts: [ConnectedAccount]?
    let premiumSince: String?
    let premiumType: Int?
    let premiumGuildSince: String?
    let profileThemesExperimentBucket: Int?
    let mutualGuilds: [MutualGuild]?
    let mutualFriends: [User]?
    let userProfile: UserProfileData?
    
    enum CodingKeys: String, CodingKey {
        case user
        case connectedAccounts = "connected_accounts"
        case premiumSince = "premium_since"
        case premiumType = "premium_type"
        case premiumGuildSince = "premium_guild_since"
        case profileThemesExperimentBucket = "profile_themes_experiment_bucket"
        case mutualGuilds = "mutual_guilds"
        case mutualFriends = "mutual_friends"
        case userProfile = "user_profile"
    }
}

struct UserProfileData: Codable {
    let bio: String?
    let accentColor: Int?
    let pronouns: String?
    let banner: String?
    let themeColors: [Int]?
    let popoutAnimationParticleType: String?
    
    enum CodingKeys: String, CodingKey {
        case bio
        case accentColor = "accent_color"
        case pronouns
        case banner
        case themeColors = "theme_colors"
        case popoutAnimationParticleType = "popout_animation_particle_type"
    }
}

struct ConnectedAccount: Codable {
    let type: String
    let id: String
    let name: String
    let verified: Bool?
    let visibility: Int?
    let showActivity: Bool?
    let metadata: ConnectedAccountMetadata?
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case verified
        case visibility
        case showActivity = "show_activity"
        case metadata
    }
}

struct ConnectedAccountMetadata: Codable {
    let itemId: String?
    let serviceName: String?
    
    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case serviceName = "service_name"
    }
}

struct MutualGuild: Codable {
    let id: String
    let nick: String?
}

extension UserProfile {
    var displayName: String {
        return user.global_name ?? user.username
    }
    
    var userTag: String {
        if user.discriminator == "0" {
            return "@\(user.username)"
        }
        return "\(user.username)#\(user.discriminator)"
    }
    
    var hasNitro: Bool {
        return premiumType != nil && premiumType! > 0
    }
    
    var bannerUrl: String? {
        if let banner = userProfile?.banner {
            return "https://cdn.discordapp.com/banners/\(user.id)/\(banner).png?size=1024"
        } else if let banner = user.banner {
            return "https://cdn.discordapp.com/banners/\(user.id)/\(banner).png?size=1024"
        }
        return nil
    }
    
    var avatarUrl: String? {
        guard let avatar = user.avatar else { return nil }
        let format = avatar.hasPrefix("a_") ? "gif" : "png"
        return "https://cdn.discordapp.com/avatars/\(user.id)/\(avatar).\(format)?size=1024"
    }
    
    var accentColorHex: String? {
        let color = userProfile?.accentColor ?? user.accentColor
        guard let colorInt = color else { return nil }
        return String(format: "#%06X", colorInt)
    }
}