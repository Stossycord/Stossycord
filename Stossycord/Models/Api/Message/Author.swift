//
//  Author.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct Author: Codable, Equatable {
    var username: String
    let avatarHash: String?
    let authorId: String
    var nick: String?
    var globalName: String?
    var bio: String?
    
    var animated: Bool {
        guard let avatarHash = avatarHash else { return false }
        // example animated picture: https://cdn.discordapp.com/avatars/978750269481418792/a_66e1f94b4d89b555dece5e1db687b041.gif?size=1024&animated=true
        // @sayborduu is cool :P
        return avatarHash.hasPrefix("a_")
    }
    
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
        case bio
    }
}

extension Author: Identifiable {
    var id: String { authorId }
}

