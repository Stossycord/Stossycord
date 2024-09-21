//
//  Author.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct Author: Codable {
    var username: String
    let avatarHash: String?
    let authorId: String
    var nick: String?
    var globalName: String?
    
    var currentname: String {
        if let nick = nick {
            return nick
        } else if let globalName = globalName {
            return globalName
        } else {
            return username
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case username
        case avatarHash = "avatar"
        case authorId = "id"
        case nick
        case globalName = "global_name"
    }
}

