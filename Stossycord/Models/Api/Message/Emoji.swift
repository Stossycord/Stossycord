//
//  Emoji.swift
//  Stossycord
//
//  Created by Stossy11 on 17/1/2026.
//

import Foundation

struct Emoji: Codable, Hashable, Identifiable, Equatable {
    let id: String?
    let name: String?
    var user: User?
    var roles: [String]?
    var available: Bool?
    let animated: Bool?
    var require_colons: Bool?
    var managed: Bool?
    var version: Int?
}

extension Emoji {
    var discordShortcode: String? {
        guard let id, let name else { return name }
        return "<\(animated == true ? "a" : ""):\(name):\(id)>"
    }
    
    var discordReactionIdentifier: String? {
        if let id, let name {
            return "\(name):\(id)"
        }
        return name
    }
    
    func cdnURLString(size: Int = 48) -> String? {
        guard let id else { return nil }
        let fileExtension = animated == true ? "gif" : "png"
        return "https://cdn.discordapp.com/emojis/\(id).\(fileExtension)?size=\(size)&name=shrug"
    }
    
    var fakeNitroMarkdown: String? {
        guard let name, let url = cdnURLString(size: 48) else { return discordShortcode }
        return "[\(name)](\(url))"
    }
}
