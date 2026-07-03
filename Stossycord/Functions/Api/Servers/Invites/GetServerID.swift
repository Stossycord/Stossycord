//
//  GetServerID.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//

import Foundation

class GetServerID: DiscordRequest<String?>, APIRequest {
    typealias Response = String?
    
    var endpoint: String = ""
    var method: String = "GET"
    
    var responseHandler: ((Data, URLResponse) -> Response)? {
        return { data, urlresponse in
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let guild = json["guild"] as? [String: Any],
               let guildID = guild["id"] as? String {
                return guildID
            }
            return nil
        }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let inviteId = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        return makeUrlRequest(url: makeAPIUrl("invites/\(inviteId)"))
    }
}

extension DiscordRequest {
    static var serverIdFromInvite: GetServerID { .init() }
}
