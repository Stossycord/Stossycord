//
//  CurrentUser.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

class GetCurrentUser: DiscordRequest<User>, APIRequest {
    typealias Response = User
    
    var endpoint: String = "users/@me"
    var method: String = "GET"
}

extension DiscordRequest {
    static var currentUser: GetCurrentUser { .init() }
}

