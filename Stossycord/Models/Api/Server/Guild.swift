//
//  Guild.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

struct Guild: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String?
    let unavailable: Bool?
    let geoRestricted: Bool?
    let joinedAt: String?
    let large: Bool?
    let memberCount: Int?
    let members: [GuildMember]?
    let channels: [Channel]?
    let threads: [Channel]?
    let presences: [Presence]?
    let voiceStates: [VoiceState]?
    let activityInstances: [EmbeddedActivityInstance]?
    let stageInstances: [StageInstance]?
    let guildScheduledEvents: [GuildScheduledEvent]?
    let dataMode: String?
    let properties: PartialGuild?
    let stickers: [Sticker]?
    let roles: [GuildRole]?
    let emojis: [Emoji]?
    let soundboardSounds: [SoundboardSound]?
    let premiumSubscriptionCount: Int?
    
    init(id: String, name: String, icon: String? = nil, unavailable: Bool? = nil, geoRestricted: Bool? = nil, joinedAt: String? = nil, large: Bool? = nil, memberCount: Int? = nil, members: [GuildMember]? = nil, channels: [Channel]? = nil, threads: [Channel]? = nil, presences: [Presence]? = nil, voiceStates: [VoiceState]? = nil, activityInstances: [EmbeddedActivityInstance]? = nil, stageInstances: [StageInstance]? = nil, guildScheduledEvents: [GuildScheduledEvent]? = nil, dataMode: String? = nil, properties: PartialGuild? = nil, stickers: [Sticker]? = nil, roles: [GuildRole]? = nil, emojis: [Emoji]? = nil, soundboardSounds: [SoundboardSound]? = nil, premiumSubscriptionCount: Int? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.unavailable = unavailable
        self.geoRestricted = geoRestricted
        self.joinedAt = joinedAt
        self.large = large
        self.memberCount = memberCount
        self.members = members
        self.channels = channels
        self.threads = threads
        self.presences = presences
        self.voiceStates = voiceStates
        self.activityInstances = activityInstances
        self.stageInstances = stageInstances
        self.guildScheduledEvents = guildScheduledEvents
        self.dataMode = dataMode
        self.properties = properties
        self.stickers = stickers
        self.roles = roles
        self.emojis = emojis
        self.soundboardSounds = soundboardSounds
        self.premiumSubscriptionCount = premiumSubscriptionCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, unavailable, large, members, channels, threads, presences, roles, emojis, stickers
        case geoRestricted = "geo_restricted"
        case joinedAt = "joined_at"
        case memberCount = "member_count"
        case voiceStates = "voice_states"
        case activityInstances = "activity_instances"
        case stageInstances = "stage_instances"
        case guildScheduledEvents = "guild_scheduled_events"
        case dataMode = "data_mode"
        case properties
        case soundboardSounds = "soundboard_sounds"
        case premiumSubscriptionCount = "premium_subscription_count"
    }
    
    var iconUrl: String? {
        return "https://cdn.discordapp.com/icons/\(id)/\(icon ?? "").png"
    }
}

extension Guild {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)

        let properties = try container.decodeIfPresent(PartialGuild.self, forKey: .properties)
        self.properties = properties

        self.name =
            (try container.decodeIfPresent(String.self, forKey: .name))
            ?? properties?.name
            ?? "Unknown Guild"

        self.icon =
            (try container.decodeIfPresent(String.self, forKey: .icon))
            ?? properties?.icon

        self.unavailable = try container.decodeIfPresent(Bool.self, forKey: .unavailable)
        self.large = try container.decodeIfPresent(Bool.self, forKey: .large)
        self.geoRestricted = try container.decodeIfPresent(Bool.self, forKey: .geoRestricted)
        self.joinedAt = try container.decodeIfPresent(String.self, forKey: .joinedAt)
        self.memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount)
        self.dataMode = try container.decodeIfPresent(String.self, forKey: .dataMode)
        self.premiumSubscriptionCount =
            try container.decodeIfPresent(Int.self, forKey: .premiumSubscriptionCount)

        self.members = try container.decodeIfPresent([GuildMember].self, forKey: .members)
        self.channels = try container.decodeIfPresent([Channel].self, forKey: .channels)
        self.threads = try container.decodeIfPresent([Channel].self, forKey: .threads)
        self.presences = try container.decodeIfPresent([Presence].self, forKey: .presences)
        self.voiceStates = try container.decodeIfPresent([VoiceState].self, forKey: .voiceStates)
        self.activityInstances =
            try container.decodeIfPresent([EmbeddedActivityInstance].self, forKey: .activityInstances)
        self.stageInstances =
            try container.decodeIfPresent([StageInstance].self, forKey: .stageInstances)
        self.guildScheduledEvents =
            try container.decodeIfPresent([GuildScheduledEvent].self, forKey: .guildScheduledEvents)

        self.roles = try container.decodeIfPresent([GuildRole].self, forKey: .roles)
        self.emojis = try container.decodeIfPresent([Emoji].self, forKey: .emojis)
        self.stickers = try container.decodeIfPresent([Sticker].self, forKey: .stickers)
        self.soundboardSounds =
            try container.decodeIfPresent([SoundboardSound].self, forKey: .soundboardSounds)
    }
}
