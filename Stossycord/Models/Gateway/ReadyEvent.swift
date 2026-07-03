//
//  ReadyEvent.swift
//  Stossycord
//
//  Created by Stossy11 on 16/1/2026.
//

import Foundation

struct ReadyEvent: Codable {
    let trace: [String]
    let v: Int
    let user: User
    let notificationSettings: NotificationSettings?
    let userGuildSettings: UserGuildSettingsWrapper?
    let readState: ReadStateWrapper?
    let guilds: [Guild]
    let guildJoinRequests: [PartialGuildJoinRequest]?
    let relationships: [Relationship]
    let gameRelationships: [GameRelationship]?
    let friendSuggestionCount: Int?
    let privateChannels: [DMs]?
    let connectedAccounts: [Connection]?
    let notes: [String: String]?
    let presences: [Presence]
    let mergedPresences: MergedPresences?
    let mergedMembers: [[GuildMember]]?
    let users: [User]?
    let linkedUsers: [LinkedUser]?
    let application: GatewayApplication?
    let scopes: [String]?
    let sessionId: String
    let sessionType: String?
    let sessions: [Session]
    let staticClientSessionId: String?
    let authSessionIdHash: String?
    let authToken: String?
    let analyticsToken: String?
    let authenticatorTypes: [Int]?
    let requiredAction: String?
    let countryCode: String?
    let geoOrderedRtcRegions: [String]?
    let consents: Consents?
    let tutorial: Tutorial?
    let shard: [Int]?
    let resumeGatewayUrl: String
    let apiCodeVersion: Int?
    let experiments: [UserExperiment]?
    let guildExperiments: [GuildExperiment]?
    let apexExperiments: ApexExperiments?
    let explicitContentScanVersion: Int?
    let pendingPayments: [Payment]?
    let avSfProtocolFloor: Int?
    let featureFlags: GatewayFeatureFlags?
    let lobbies: [Lobby]?
    let userApplicationProfiles: [String: [UserApplicationProfile]]?
    
    enum CodingKeys: String, CodingKey {
        case trace = "_trace"
        case v
        case user
        case notificationSettings = "notification_settings"
        case userGuildSettings = "user_guild_settings"
        case readState = "read_state"
        case guilds
        case guildJoinRequests = "guild_join_requests"
        case relationships
        case gameRelationships = "game_relationships"
        case friendSuggestionCount = "friend_suggestion_count"
        case privateChannels = "private_channels"
        case connectedAccounts = "connected_accounts"
        case notes
        case presences
        case mergedPresences = "merged_presences"
        case mergedMembers = "merged_members"
        case users
        case linkedUsers = "linked_users"
        case application
        case scopes
        case sessionId = "session_id"
        case sessionType = "session_type"
        case sessions
        case staticClientSessionId = "static_client_session_id"
        case authSessionIdHash = "auth_session_id_hash"
        case authToken = "auth_token"
        case analyticsToken = "analytics_token"
        case authenticatorTypes = "authenticator_types"
        case requiredAction = "required_action"
        case countryCode = "country_code"
        case geoOrderedRtcRegions = "geo_ordered_rtc_regions"
        case consents
        case tutorial
        case shard
        case resumeGatewayUrl = "resume_gateway_url"
        case apiCodeVersion = "api_code_version"
        case experiments
        case guildExperiments = "guild_experiments"
        case apexExperiments = "apex_experiments"
        case explicitContentScanVersion = "explicit_content_scan_version"
        case pendingPayments = "pending_payments"
        case avSfProtocolFloor = "av_sf_protocol_floor"
        case featureFlags = "feature_flags"
        case lobbies
        case userApplicationProfiles = "user_application_profiles"
    }
}

extension ReadyEvent {
    var readStateMap: [String: String] {
        let entries: [ReadState]
        switch readState {
        case .versioned(let v): entries = v.entries
        case .regular(let r):   entries = r
        case nil:               return [:]
        }
        return Dictionary(uniqueKeysWithValues: entries.compactMap { state in
            guard let lastMessageId = state.lastMessageId else { return nil }
            return (state.id, lastMessageId)
        })
    }
}

enum UserGuildSettingsWrapper: Codable {
    case versioned(VersionedArray<UserGuildSettings>)
    case regular([UserGuildSettings])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let versioned = try? container.decode(VersionedArray<UserGuildSettings>.self) {
            self = .versioned(versioned)
        } else if let regular = try? container.decode([UserGuildSettings].self) {
            self = .regular(regular)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid user_guild_settings format")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .versioned(let versioned):
            try container.encode(versioned)
        case .regular(let regular):
            try container.encode(regular)
        }
    }
}

enum ReadStateWrapper: Codable {
    case versioned(VersionedArray<ReadState>)
    case regular([ReadState])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        var versionedError: Error?
        var regularError: Error?
        
        do {
            self = .versioned(try container.decode(VersionedArray<ReadState>.self))
            return
        } catch {
            versionedError = error
        }
        
        do {
            self = .regular(try container.decode([ReadState].self))
            return
        } catch {
            regularError = error
        }
        
        print("ReadStateWrapper versioned error: \(versionedError!)")
        print("ReadStateWrapper regular error: \(regularError!)")
    
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid read_state format. Versioned: \(versionedError!). Regular: \(regularError!)"
        )
    }
}


struct VersionedArray<T: Codable>: Codable {
    let entries: [T]
    let partial: Bool
    let version: Int
}

struct MergedPresences: Codable {
    let friends: [Presence]?
    let guilds: [[Presence]]?
}


struct PartialGuildJoinRequest: Codable {
    let guildId: String?
    
    enum CodingKeys: String, CodingKey {
        case guildId = "guild_id"
    }
}

struct Relationship: Codable {
    let id: String
    let type: Int
    let nickname: String?
    let user: User?
    let since: String?
}

struct GameRelationship: Codable {
    let id: String
    let applicationId: String
    let type: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case type
    }
}

struct Connection: Codable {
    let type: String
    let id: String
    let name: String
    let verified: Bool?
    let friendSync: Bool?
    let showActivity: Bool?
    let visibility: Int?
    
    enum CodingKeys: String, CodingKey {
        case type, id, name, verified, visibility
        case friendSync = "friend_sync"
        case showActivity = "show_activity"
    }
}

struct Presence: Codable, Hashable {
    let user: User
    let status: String
    let activities: [Activity]?
    let clientStatus: ClientStatus?
    
    enum CodingKeys: String, CodingKey {
        case user, status, activities
        case clientStatus = "client_status"
    }
}

struct PartialPresence: Codable, Hashable {
    let status: String
    let activities: [Activity]?
    let clientStatus: ClientStatus?
    
    enum CodingKeys: String, CodingKey {
        case status, activities
        case clientStatus = "client_status"
    }
}


struct Activity: Codable, Hashable {
    let name: String
    let type: Int
    let url: String?
}

struct ClientStatus: Codable, Hashable {
    let desktop: String?
    let mobile: String?
    let web: String?
}

struct LinkedUser: Codable {
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct GatewayApplication: Codable {
    let id: String
    let flags: Int
    let name: String?
}

struct Session: Codable {
    let sessionId: String
    let status: String
    let activities: [Activity]?
    
    enum CodingKeys: String, CodingKey {
        case status, activities
        case sessionId = "session_id"
    }
}

struct NotificationSettings: Codable {
}

struct UserGuildSettings: Codable {
    let guildId: String?
    
    enum CodingKeys: String, CodingKey {
        case guildId = "guild_id"
    }
}

struct ReadState: Codable {
    let id: String
    let lastMessageId: String?
    let mentionCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case lastMessageId = "last_message_id"
        case mentionCount = "mention_count"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mentionCount = try container.decodeIfPresent(Int.self, forKey: .mentionCount)
        
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .lastMessageId) {
            lastMessageId = stringValue
        } else if let intValue = try? container.decodeIfPresent(Int64.self, forKey: .lastMessageId) {
            lastMessageId = String(intValue)
        } else {
            lastMessageId = nil
        }
    }
}

struct Consents: Codable {
}

struct Tutorial: Codable {
    let indicatorsSuppressed: Bool?
    let indicatorsConfirmed: [String]?
    
    enum CodingKeys: String, CodingKey {
        case indicatorsSuppressed = "indicators_suppressed"
        case indicatorsConfirmed = "indicators_confirmed"
    }
}

struct UserExperiment: Codable {
}

struct GuildExperiment: Codable {
}

struct ApexExperiments: Codable {
}

struct Payment: Codable {
}

struct GatewayFeatureFlags: Codable {
    let disabledFunctions: [String]?
    let disabledGatewayEvents: [String]?
    
    enum CodingKeys: String, CodingKey {
        case disabledFunctions = "disabled_functions"
        case disabledGatewayEvents = "disabled_gateway_events"
    }
}

struct Lobby: Codable {
    let id: String
}

struct UserApplicationProfile: Codable {
    let username: String?
    let metadata: String?
    let externalId: UserApplicationProfileExternalId?
    let avatarHash: String?
    
    enum CodingKeys: String, CodingKey {
        case username, metadata
        case externalId = "external_id"
        case avatarHash = "avatar_hash"
    }
}

struct UserApplicationProfileExternalId: Codable {
    let providerType: String?
    let providerIssuedUserId: String?
    let providerId: String?
    let preferredGlobalName: String?
    
    enum CodingKeys: String, CodingKey {
        case providerType = "provider_type"
        case providerIssuedUserId = "provider_issued_user_id"
        case providerId = "provider_id"
        case preferredGlobalName = "preferred_global_name"
    }
}

// MARK: - Additional Gateway Types

struct VoiceState: Codable {
    let channelId: String?
    let userId: String
    let sessionId: String
    let deaf: Bool
    let mute: Bool
    let selfDeaf: Bool
    let selfMute: Bool
    
    enum CodingKeys: String, CodingKey {
        case deaf, mute
        case channelId = "channel_id"
        case userId = "user_id"
        case sessionId = "session_id"
        case selfDeaf = "self_deaf"
        case selfMute = "self_mute"
    }
}

struct EmbeddedActivityInstance: Codable {
    // Add specific fields as needed
}

struct StageInstance: Codable {
    let id: String
    let channelId: String
    let topic: String
    
    enum CodingKeys: String, CodingKey {
        case id, topic
        case channelId = "channel_id"
    }
}

struct GuildScheduledEvent: Codable {
    let id: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct PartialGuild: Codable {
    // Properties object when using CLIENT_STATE_V2 capability
    let id: String?
    let name: String?
    let icon: String?
}

struct Sticker: Codable {
    let id: String
    let name: String
}

struct GuildRole: Codable {
    let id: String
    let name: String
    let color: Int
    let position: Int
    let permissions: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, position, permissions
    }
}


struct SoundboardSound: Codable {
    let soundId: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case soundId = "sound_id"
        case name
    }
}
