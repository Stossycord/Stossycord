//
//  SendTypingIndicator.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import Foundation

class SendTypingIndicator: DiscordRequest<String?>, APIRequest {
    typealias Response = String?
    
    var endpoint: String = ""
    var method: String = "POST"
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let channel = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        return makeUrlRequest(url: makeAPIUrl("channels/\(channel)/typing"))
    }
}

extension DiscordRequest {
    static var typingIndicator: SendTypingIndicator { .init() }
}

