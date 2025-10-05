//
//  GuildAdvanced.swift
//  Stossycord
//
//  Created by Stossy11 on 26/12/2024.
//

import Foundation

struct AdvancedGuild: Codable {
    struct Role: Codable, Equatable {
        let id: String
        let name: String
        let description: String?
        let permissions: String
        let position: Int
        let color: Int
        let hoist: Bool
        let managed: Bool
        let mentionable: Bool
        let icon: String?
        let unicodeEmoji: String?
        let flags: Int
    }

    let id: String
    let name: String
    let icon: String?
    let description: String?
    let homeHeader: String?
    let splash: String?
    let discoverySplash: String?
    let features: [String]
    let emojis: [String]
    let stickers: [String]
    let banner: String?
    let ownerID: String
    let applicationID: String?
    let region: String?
    let afkChannelID: String?
    let afkTimeout: Int
    let systemChannelID: String?
    let widgetEnabled: Bool
    let widgetChannelID: String?
    let verificationLevel: Int
    let roles: [Role]
    let defaultMessageNotifications: Int
    let mfaLevel: Int
    let explicitContentFilter: Int
    let maxPresences: Int?
    let maxMembers: Int
    let maxStageVideoChannelUsers: Int
    let maxVideoChannelUsers: Int
    let vanityURLCode: String?
    let premiumTier: Int
    let premiumSubscriptionCount: Int
    let systemChannelFlags: Int
    let preferredLocale: String
    let rulesChannelID: String?
    let safetyAlertsChannelID: String?
    let publicUpdatesChannelID: String?
    let hubType: String?
    let premiumProgressBarEnabled: Bool
    let latestOnboardingQuestionID: String?
    let incidentsData: String?
    let nsfw: Bool
    let nsfwLevel: Int
}
