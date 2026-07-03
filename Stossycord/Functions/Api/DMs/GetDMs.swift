//
//  GetDMs.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import Foundation

class GetDms: DiscordRequest<[DMs]>, APIRequest {
    typealias Response = [DMs]
    
    var responseHandler: ((Data, URLResponse) -> [DMs])? = { data, _ in
        
        if !data.isEmpty, var data = try? JSONDecoder().decode(Response.self, from: data) {
            data.sort { cool, cool2 in
                cool.position > cool2.position
            }
            
            return data
        }
        
        return []
    }
    
    var endpoint: String = "users/@me/channels"
    var method: String = "GET"
}

extension DiscordRequest {
    static var directMessages: GetDms { .init() }
}
