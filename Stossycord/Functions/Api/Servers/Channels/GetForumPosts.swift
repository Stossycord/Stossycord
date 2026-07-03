//
//  GetForumPosts.swift
//  Stossycord
//
//  Created by Stossy11 on 2/7/2026.
//

import Foundation

struct ForumPostsResponse: Codable {
    let threads: [Channel]
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case threads
        case hasMore = "has_more"
    }
}

class GetForumPosts: DiscordRequest<ForumPostsResponse>, APIRequest {
    typealias Response = ForumPostsResponse

    var endpoint: String = ""
    var method: String = "GET"

    var responseHandler: ((Data, URLResponse) -> ForumPostsResponse)? {
        { data, _ in
            if let response = try? JSONDecoder().decode(ForumPostsResponse.self, from: data) {
                return response
            }

            if let errorObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorObject["message"] as? String {
                print("Forum posts request returned: \(message)")
            }

            return ForumPostsResponse(threads: [], hasMore: nil)
        }
    }

    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let channelId = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        let offset = args.dropFirst().first as? Int ?? 0

        var components = URLComponents(url: makeAPIUrl("channels/\(channelId)/threads/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "archived", value: "true"),
            URLQueryItem(name: "sort_by", value: "last_message_time"),
            URLQueryItem(name: "sort_order", value: "desc"),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "tag_setting", value: "match_some"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else { return nil }
        return makeUrlRequest(url: url)
    }
}

class GetActiveThreads: DiscordRequest<ForumPostsResponse>, APIRequest {
    typealias Response = ForumPostsResponse

    var endpoint: String = ""
    var method: String = "GET"

    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let guildId = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }

        return makeUrlRequest(url: makeAPIUrl("guilds/\(guildId)/threads/active"))
    }
}

extension DiscordRequest {
    static var forumPosts: GetForumPosts { .init() }
    static var activeThreads: GetActiveThreads { .init() }
}
