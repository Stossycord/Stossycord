//
//  LeaveServer.swift
//  Stossycord
//
//  Created by GitHub Copilot on 05/10/2025.
//

import Foundation

class LeaveGuild: DiscordRequest<[String]>, APIRequest {
    typealias Response = [String]
    
    var endpoint: String = "users/@me/guilds"
    var method: String = "DELETE"
    
    var responseHandler: ((Data, URLResponse) -> Response)? {
        { _, _ in
            return []
        }
    }
    
    func makeBody() -> Data? {
        let body: [String: Any] = ["lurking": false]
        return try? JSONSerialization.data(withJSONObject: body, options: [])
    }
}

extension DiscordRequest {
    static var leaveGuild: LeaveGuild { .init() }
}
