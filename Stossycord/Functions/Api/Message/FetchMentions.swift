//
//  FetchMentions.swift
//  Stossycord
//
//  Created by Stossy11 on 4/5/2026.
//


import Foundation

class FetchMentions: DiscordRequest<[DiscordMentionMessage]>, APIRequest {
    typealias Response = [DiscordMentionMessage]
    
    var endpoint: String = ""
    var method: String = "GET"
    
    var responseHandler: ((Data, URLResponse) -> Response)? {
        { data, _ in
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .valueNotFound(let type, let context):
                        print("Value not found: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted at: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                return []
            }
        }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        let limit = args.first as? Int ?? 25
        let roles = args[safe: 1] as? Bool ?? true
        let everyone = args[safe: 2] as? Bool ?? true
        
        return makeUrlRequest(
            url: makeAPIUrl("users/@me/mentions?limit=\(limit)&roles=\(roles)&everyone=\(everyone)")
        )
    }
}

struct DiscordMentionMessage: Codable {
    let id: String
    let channelId: String
    let guildId: String?
    let author: User
    let content: String
    let timestamp: String
    let mentionEveryone: Bool
    let mentions: [User]
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, author, mentions
        case channelId = "channel_id"
        case guildId = "guild_id"
        case mentionEveryone = "mention_everyone"
    }
}

extension DiscordRequest {
    static var fetchMentions: FetchMentions { .init() }
}
