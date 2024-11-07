//
//  GuildMemberResponse.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//


import Foundation

struct GuildMemberResponse: Codable {
    let userId: String
    let username: String
    let joinedAt: String
    let isPending: Bool
}
