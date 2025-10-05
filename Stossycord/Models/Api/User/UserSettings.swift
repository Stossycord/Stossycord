import Foundation

struct UserSettings: Codable {
    let locale: String?
    let theme: String?
    let developerMode: Bool?
    let afkTimeout: Int?
    let status: String?
    let customStatus: CustomStatus?
    let allowAccessibilityDetection: Bool?
    let detectPlatformAccounts: Bool?
    let defaultGuildsRestricted: Bool?
    let inlineAttachmentMedia: Bool?
    let inlineEmbedMedia: Bool?
    let gifAutoPlay: Bool?
    let renderEmbeds: Bool?
    let renderReactions: Bool?
    let animateEmoji: Bool?
    let enableTtsCommand: Bool?
    let messageDisplayCompact: Bool?
    let convertEmoticons: Bool?
    let showCurrentGame: Bool?
    let guildFolders: [GuildFolder]?
    let explicitContentFilter: Int?
    let disableGamesTab: Bool?
    let animateStickers: Bool?
    let viewNsfwGuilds: Bool?
    let viewNsfwCommands: Bool?
    let streamNotificationsEnabled: Bool?
    let contactSyncEnabled: Bool?
    let timezoneOffset: Int?
    let passwordless: Bool?
    let nativePhoneIntegrationEnabled: Bool?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        locale = try container.decodeIfPresent(String.self, forKey: .locale)
        theme = try container.decodeIfPresent(String.self, forKey: .theme)
        
        // Handle integer-to-boolean conversion for Discord's format
        developerMode = try container.decodeIntAsBool(forKey: .developerMode)
        afkTimeout = try container.decodeIfPresent(Int.self, forKey: .afkTimeout)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        customStatus = try container.decodeIfPresent(CustomStatus.self, forKey: .customStatus)
        allowAccessibilityDetection = try container.decodeIntAsBool(forKey: .allowAccessibilityDetection)
        detectPlatformAccounts = try container.decodeIntAsBool(forKey: .detectPlatformAccounts)
        defaultGuildsRestricted = try container.decodeIntAsBool(forKey: .defaultGuildsRestricted)
        inlineAttachmentMedia = try container.decodeIntAsBool(forKey: .inlineAttachmentMedia)
        inlineEmbedMedia = try container.decodeIntAsBool(forKey: .inlineEmbedMedia)
        gifAutoPlay = try container.decodeIntAsBool(forKey: .gifAutoPlay)
        renderEmbeds = try container.decodeIntAsBool(forKey: .renderEmbeds)
        renderReactions = try container.decodeIntAsBool(forKey: .renderReactions)
        animateEmoji = try container.decodeIntAsBool(forKey: .animateEmoji)
        enableTtsCommand = try container.decodeIntAsBool(forKey: .enableTtsCommand)
        messageDisplayCompact = try container.decodeIntAsBool(forKey: .messageDisplayCompact)
        convertEmoticons = try container.decodeIntAsBool(forKey: .convertEmoticons)
        showCurrentGame = try container.decodeIntAsBool(forKey: .showCurrentGame)
        guildFolders = try container.decodeIfPresent([GuildFolder].self, forKey: .guildFolders)
        explicitContentFilter = try container.decodeIfPresent(Int.self, forKey: .explicitContentFilter)
        disableGamesTab = try container.decodeIntAsBool(forKey: .disableGamesTab)
        animateStickers = try container.decodeIntAsBool(forKey: .animateStickers)
        viewNsfwGuilds = try container.decodeIntAsBool(forKey: .viewNsfwGuilds)
        viewNsfwCommands = try container.decodeIntAsBool(forKey: .viewNsfwCommands)
        streamNotificationsEnabled = try container.decodeIntAsBool(forKey: .streamNotificationsEnabled)
        contactSyncEnabled = try container.decodeIntAsBool(forKey: .contactSyncEnabled)
        timezoneOffset = try container.decodeIfPresent(Int.self, forKey: .timezoneOffset)
        passwordless = try container.decodeIntAsBool(forKey: .passwordless)
        nativePhoneIntegrationEnabled = try container.decodeIntAsBool(forKey: .nativePhoneIntegrationEnabled)
    }
    
    enum CodingKeys: String, CodingKey {
        case locale
        case theme
        case developerMode = "developer_mode"
        case afkTimeout = "afk_timeout"
        case status
        case customStatus = "custom_status"
        case allowAccessibilityDetection = "allow_accessibility_detection"
        case detectPlatformAccounts = "detect_platform_accounts"
        case defaultGuildsRestricted = "default_guilds_restricted"
        case inlineAttachmentMedia = "inline_attachment_media"
        case inlineEmbedMedia = "inline_embed_media"
        case gifAutoPlay = "gif_auto_play"
        case renderEmbeds = "render_embeds"
        case renderReactions = "render_reactions"
        case animateEmoji = "animate_emoji"
        case enableTtsCommand = "enable_tts_command"
        case messageDisplayCompact = "message_display_compact"
        case convertEmoticons = "convert_emoticons"
        case showCurrentGame = "show_current_game"
        case guildFolders = "guild_folders"
        case explicitContentFilter = "explicit_content_filter"
        case disableGamesTab = "disable_games_tab"
        case animateStickers = "animate_stickers"
        case viewNsfwGuilds = "view_nsfw_guilds"
        case viewNsfwCommands = "view_nsfw_commands"
        case streamNotificationsEnabled = "stream_notifications_enabled"
        case contactSyncEnabled = "contact_sync_enabled"
        case timezoneOffset = "timezone_offset"
        case passwordless
        case nativePhoneIntegrationEnabled = "native_phone_integration_enabled"
    }
    
    init(locale: String? = nil, theme: String? = nil, developerMode: Bool? = nil, afkTimeout: Int? = nil, status: String? = nil, customStatus: CustomStatus? = nil, allowAccessibilityDetection: Bool? = nil, detectPlatformAccounts: Bool? = nil, defaultGuildsRestricted: Bool? = nil, inlineAttachmentMedia: Bool? = nil, inlineEmbedMedia: Bool? = nil, gifAutoPlay: Bool? = nil, renderEmbeds: Bool? = nil, renderReactions: Bool? = nil, animateEmoji: Bool? = nil, enableTtsCommand: Bool? = nil, messageDisplayCompact: Bool? = nil, convertEmoticons: Bool? = nil, showCurrentGame: Bool? = nil, guildFolders: [GuildFolder]? = nil, explicitContentFilter: Int? = nil, disableGamesTab: Bool? = nil, animateStickers: Bool? = nil, viewNsfwGuilds: Bool? = nil, viewNsfwCommands: Bool? = nil, streamNotificationsEnabled: Bool? = nil, contactSyncEnabled: Bool? = nil, timezoneOffset: Int? = nil, passwordless: Bool? = nil, nativePhoneIntegrationEnabled: Bool? = nil) {
        self.locale = locale
        self.theme = theme
        self.developerMode = developerMode
        self.afkTimeout = afkTimeout
        self.status = status
        self.customStatus = customStatus
        self.allowAccessibilityDetection = allowAccessibilityDetection
        self.detectPlatformAccounts = detectPlatformAccounts
        self.defaultGuildsRestricted = defaultGuildsRestricted
        self.inlineAttachmentMedia = inlineAttachmentMedia
        self.inlineEmbedMedia = inlineEmbedMedia
        self.gifAutoPlay = gifAutoPlay
        self.renderEmbeds = renderEmbeds
        self.renderReactions = renderReactions
        self.animateEmoji = animateEmoji
        self.enableTtsCommand = enableTtsCommand
        self.messageDisplayCompact = messageDisplayCompact
        self.convertEmoticons = convertEmoticons
        self.showCurrentGame = showCurrentGame
        self.guildFolders = guildFolders
        self.explicitContentFilter = explicitContentFilter
        self.disableGamesTab = disableGamesTab
        self.animateStickers = animateStickers
        self.viewNsfwGuilds = viewNsfwGuilds
        self.viewNsfwCommands = viewNsfwCommands
        self.streamNotificationsEnabled = streamNotificationsEnabled
        self.contactSyncEnabled = contactSyncEnabled
        self.timezoneOffset = timezoneOffset
        self.passwordless = passwordless
        self.nativePhoneIntegrationEnabled = nativePhoneIntegrationEnabled
    }
    
    struct CustomStatus: Codable {
        let text: String?
        let emojiId: String?
        let emojiName: String?
        let expiresAt: String?
        
        enum CodingKeys: String, CodingKey {
            case text
            case emojiId = "emoji_id"
            case emojiName = "emoji_name"
            case expiresAt = "expires_at"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            text = try container.decodeIfPresent(String.self, forKey: .text)
            
            // Handle emoji_id which can be a number or string
            if let emojiIdInt = try? container.decode(Int64.self, forKey: .emojiId) {
                emojiId = String(emojiIdInt)
            } else {
                emojiId = try container.decodeIfPresent(String.self, forKey: .emojiId)
            }
            
            emojiName = try container.decodeIfPresent(String.self, forKey: .emojiName)
            
            // Handle expires_at which can be null or a string
            if let expiresAtString = try? container.decode(String.self, forKey: .expiresAt), expiresAtString != "<null>" {
                expiresAt = expiresAtString
            } else {
                expiresAt = nil
            }
        }
    }
    
    struct GuildFolder: Codable {
        let id: Int?
        let name: String?
        let color: Int?
        let guildIds: [String]
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case color
            case guildIds = "guild_ids"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Handle null values for id which come as "<null>" strings
            if let idString = try? container.decode(String.self, forKey: .id), idString != "<null>" {
                id = Int(idString)
            } else if let idInt = try? container.decode(Int.self, forKey: .id) {
                id = idInt
            } else {
                id = nil
            }
            
            // Handle null values for name which come as "<null>" strings
            if let nameString = try? container.decode(String.self, forKey: .name), nameString != "<null>" {
                name = nameString
            } else {
                name = nil
            }
            
            // Handle null values for color which come as "<null>" strings or actual nulls
            if let colorInt = try? container.decode(Int.self, forKey: .color) {
                color = colorInt
            } else {
                color = nil
            }
            
            guildIds = try container.decode([String].self, forKey: .guildIds)
        }
    }
}

// Helper extension for decoding Discord's integer-boolean format
extension KeyedDecodingContainer {
    func decodeIntAsBool(forKey key: Key) -> Bool? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue != 0
        } else if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue
        }
        return nil
    }
}