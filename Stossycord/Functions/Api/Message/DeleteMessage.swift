//
//  DeleteMessage.swift
//  Stossycord
//
//  Created by Stossy11 on 24/03/2025.
//

import Foundation

class DeleteMessage: DiscordRequest<String>, APIRequest {
    
    typealias Response = [Message]
    
    var endpoint: String = ""
    var method: String = "DELETE"
    
    var args: (String, String)
    
    init(channel: String, messageId: String) {
        args = (channel, messageId)
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        return makeUrlRequest(url: makeAPIUrl("\(self.args.0)/messages/\(self.args.1)"))
    }
}

extension DiscordRequest {
    static func deleteMessage(channel: String, messageId: String) -> DeleteMessage { .init(channel: channel, messageId: messageId) }
}

