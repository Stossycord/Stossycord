//
//  GetServerRoles.swift
//  Stossycord
//
//  Created by Stossy11 on 26/12/2024.
//

import Foundation

class GetGuildRoles: DiscordRequest<[AdvancedGuild.Role]>, APIRequest {
    typealias Response = [AdvancedGuild.Role]
    
    var endpoint: String = ""
    var method: String = "GET"
    
    var responseHandler: ((Data, URLResponse) -> [AdvancedGuild.Role])? {
        { data, _ in
            var array = (try? JSONDecoder().decode(Response.self, from: data)) ?? []
            
            array.sort {
                $0.position > $1.position
            }
            
            return array
        }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let guildId = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        return makeUrlRequest(url: makeAPIUrl("guilds/\(guildId)/roles"))
    }
}

extension DiscordRequest {
    static var roles: GetGuildRoles { .init() }
}
