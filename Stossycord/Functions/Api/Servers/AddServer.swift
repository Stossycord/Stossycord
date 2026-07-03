//
//  AddServer.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//

import Foundation

class JoinGuild: DiscordRequest<String>, APIRequest {
    typealias Response = String
    
    var endpoint: String = ""
    var method: String = "PUT"
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let guildId = args.first as? String else {
            return nil
        }
        
        let lurker = args[safe: 1] as? Bool
        let sessionId = args[safe: 2] as? String
        let location = args[safe: 3] as? String
        let recommendationLoadId = args[safe: 4] as? String
        
        var request = makeUrlRequest(url: makeAPIUrl("guilds/\(guildId)/members/@me"))
        
        var requestBody: [String: Any] = [:]
        if let lurker = lurker {
            requestBody["lurker"] = lurker
        }
        if let sessionId = sessionId {
            requestBody["session_id"] = sessionId
        } else {
            requestBody["lurker"] = false
        }
        if let location = location {
            requestBody["location"] = location
        }
        if let recommendationLoadId = recommendationLoadId {
            requestBody["recommendation_load_id"] = recommendationLoadId
        }
        
        if !requestBody.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) {
            request.httpBody = jsonData
        }
        
        return request
    }
}

extension DiscordRequest {
    static var joinGuild: JoinGuild { .init() }
}
