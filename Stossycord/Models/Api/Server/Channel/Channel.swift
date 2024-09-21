//
//  Channel.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

struct Channel: Codable {
    let id: String
    let name: String
    let type: Int
    let lastMessage: Message?
}
