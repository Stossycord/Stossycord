//
//  Reactions.swift
//  Stossycord
//
//  Created by Stossy11 on 29/1/2026.
//

import Foundation


struct Reaction: Codable, Equatable, Identifiable, Hashable {
    var id = UUID().uuidString
    var emoji: Emoji
    var count: Int
    var count_details: CountDetails?
    var burst_colors: [String]? // Unknown rn
    var me_burst: Bool?
    var burst_me: Bool?
    var me: Bool?
    var burst_count: Int?
    
    enum CodingKeys: CodingKey {
        case emoji
        case count
        case count_details
        case burst_colors
        case me_burst
        case burst_me
        case me
        case burst_count
    }
    
    init(id: String = UUID().uuidString, emoji: Emoji, count: Int, count_details: CountDetails? = nil, burst_colors: [String]? = nil, me_burst: Bool? = nil, burst_me: Bool? = nil, me: Bool? = nil, burst_count: Int? = nil) {
        self.id = id
        self.emoji = emoji
        self.count = count
        self.count_details = count_details
        self.burst_colors = burst_colors
        self.me_burst = me_burst
        self.burst_me = burst_me
        self.me = me
        self.burst_count = burst_count
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.emoji = try container.decode(Emoji.self, forKey: .emoji)
        self.count = try container.decode(Int.self, forKey: .count)
        self.count_details = try container.decodeIfPresent(CountDetails.self, forKey: .count_details)
        self.burst_colors = try container.decodeIfPresent([String].self, forKey: .burst_colors)
        self.me_burst = try container.decodeIfPresent(Bool.self, forKey: .me_burst)
        self.burst_me = try container.decodeIfPresent(Bool.self, forKey: .burst_me)
        self.me = try container.decodeIfPresent(Bool.self, forKey: .me)
        self.burst_count = try container.decodeIfPresent(Int.self, forKey: .burst_count)
    }
}

struct MessageReaction: Codable, Equatable {
    var user_id: String
    var channel_id: String
    var message_id: String
    var message_author_id: String?
    var guild_id: String?
    var member: ReactionMember?
    var emoji: Emoji
    var type: Int
    var burst_colors: [String]?
}

struct ReactionMember: Codable, Equatable, Hashable {
    var roles: [String]
    var user: User
}

struct CountDetails: Codable, Equatable, Hashable {
    var burst: Int
    var normal: Int
}

struct EmptyDiscordResponse: Decodable {}

class AddReaction: DiscordRequest<EmptyDiscordResponse>, APIRequest {
    typealias Response = EmptyDiscordResponse
    
    var endpoint: String = ""
    var method: String = "PUT"
    private let channelId: String
    private let messageId: String
    private let emoji: Emoji
    
    init(channelId: String, messageId: String, emoji: Emoji) {
        self.channelId = channelId
        self.messageId = messageId
        self.emoji = emoji
    }
    
    var responseHandler: ((Data, URLResponse) -> Response)? {
        { _, _ in EmptyDiscordResponse() }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let encodedEmoji = emoji.discordReactionIdentifier?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        
        return makeUrlRequest(url: makeAPIUrl("channels/\(channelId)/messages/\(messageId)/reactions/\(encodedEmoji)/@me"), json: false)
    }
}

class DeleteOwnReaction: DiscordRequest<EmptyDiscordResponse>, APIRequest {
    typealias Response = EmptyDiscordResponse
    
    var endpoint: String = ""
    var method: String = "DELETE"
    private let channelId: String
    private let messageId: String
    private let emoji: Emoji
    
    init(channelId: String, messageId: String, emoji: Emoji) {
        self.channelId = channelId
        self.messageId = messageId
        self.emoji = emoji
    }
    
    var responseHandler: ((Data, URLResponse) -> Response)? {
        { _, _ in EmptyDiscordResponse() }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let encodedEmoji = emoji.discordReactionIdentifier?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        
        return makeUrlRequest(url: makeAPIUrl("channels/\(channelId)/messages/\(messageId)/reactions/\(encodedEmoji)/@me"), json: false)
    }
}

extension DiscordRequest {
    static func addReaction(channelId: String, messageId: String, emoji: Emoji) -> AddReaction {
        .init(channelId: channelId, messageId: messageId, emoji: emoji)
    }
    
    static func deleteOwnReaction(channelId: String, messageId: String, emoji: Emoji) -> DeleteOwnReaction {
        .init(channelId: channelId, messageId: messageId, emoji: emoji)
    }
}
