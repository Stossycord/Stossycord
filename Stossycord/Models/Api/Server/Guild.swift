//
//  Guild.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

struct Guild: Codable {
    let id: String
    let name: String
    let icon: String?
    
    var iconUrl: String? {
        return "https://cdn.discordapp.com/icons/\(id)/\(icon ?? "").png"
        return nil
    }
}
