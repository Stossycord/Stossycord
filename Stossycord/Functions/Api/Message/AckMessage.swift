//
//  AckMessage.swift
//  Stossycord
//
//  Created by Stossy11 on 4/5/2026.
//


import Foundation

class AckMessage: DiscordRequest<AckResponse>, APIRequest {
    typealias Response = AckResponse
    
    var endpoint: String = ""
    var method: String = "POST"
    
    var args: (channelId: String, messageId: String, ackToken: String?)
    
    init(channelId: String, messageId: String, ackToken: String? = nil) {
        args = (channelId, messageId, ackToken)
    }

    var responseHandler: ((Data, URLResponse) -> Response)? {
        { data, _ in
            guard !data.isEmpty else { return AckResponse(token: nil) }
            return (try? JSONDecoder().decode(AckResponse.self, from: data)) ?? AckResponse(token: nil)
        }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        var request = makeUrlRequest(
            url: makeAPIUrl("channels/\(self.args.channelId)/messages/\(self.args.messageId)/ack"),
            json: true
        )
        
        var body: [String: Any] = [:]
        if let token = self.args.ackToken {
            body["token"] = token
        } else {
            body["token"] = NSNull()
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
}

struct AckResponse: Codable {
    let token: String?
}

extension DiscordRequest {
    static func ackMessage(channelId: String, messageId: String, ackToken: String? = nil) -> AckMessage {
        .init(channelId: channelId, messageId: messageId, ackToken: ackToken)
    }
}
