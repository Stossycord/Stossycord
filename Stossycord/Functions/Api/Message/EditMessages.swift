//
//  EditMessages.swift
//  Stossycord
//
//  Created by Stossy11 on 26/12/2024.
//

import Foundation

class EditMessage: DiscordRequest<Message>, APIRequest {
    typealias Response = Message
    
    var endpoint: String = ""
    var method: String = "PATCH"
    
    var content: String
    var messageId: String
    var channel: String
    
    init(channel: String, messageId: String, content: String) {
        self.channel = channel
        self.messageId = messageId
        self.content = content
    }
    
    func makeBody() -> Data? {
        let body: [String: Any] = [
            "content": content
        ]
        
        return try? JSONSerialization.data(withJSONObject: body, options: [])
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        return makeUrlRequest(url: makeAPIUrl("channels/\(channel)/messages/\(messageId)"))
    }
}

extension DiscordRequest {
    static func editMessage(channel: String, messageId: String, content: String) -> EditMessage { .init(channel: channel, messageId: messageId, content: content) }
}
