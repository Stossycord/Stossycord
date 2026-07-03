//
//  GetMessages.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

class GetMessages: DiscordRequest<[Message]>, APIRequest {
    
    typealias Response = [Message]
    
    var endpoint: String = ""
    var method: String = "GET"
    var guildId: String? = nil
    
    var responseHandler: ((Data, URLResponse) -> Response)? {
        { data, _ in
            print(String(data: data, encoding: .utf8)!)
            
            do {
                var array = try JSONDecoder().decode(Response.self, from: data)
                
                for index in array.indices {
                    guard array[index].guildId == nil else { continue }
                    
                    array[index].guildId = self.guildId
                }
                
                
                return array
            } catch {
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        
                        print("Context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        print("Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type: \(type)")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted")
                        print("Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                
                return []
            }
        }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let currentChannel = args.first as? String else {
            return nil
        }
        
        
        self.guildId = args[safe: 1] as? String
        
        let messagesAfter = args[safe: 2] as? String
        let messagesBefore = args[safe: 3] as? String
        
        var messageLimit: Int
        if let requestedLimit = args[safe: 4] as? Int {
            messageLimit = max(1, min(requestedLimit, 100))
        } else if #available(iOS 17, *)  {
            messageLimit = 100
        } else if #available(iOS 16, *)  {
            messageLimit = 50
        } else {
            messageLimit = 25
        }
        
        var components = URLComponents(url: makeAPIUrl("channels/\(currentChannel)/messages"), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "limit", value: String(messageLimit))]
        if let messagesAfter, !messagesAfter.isEmpty {
            queryItems.append(URLQueryItem(name: "after", value: messagesAfter))
        }
        if let messagesBefore, !messagesBefore.isEmpty {
            queryItems.append(URLQueryItem(name: "before", value: messagesBefore))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else { return nil }
        return makeUrlRequest(url: url)
    }
}

extension DiscordRequest {
    static var messages: GetMessages { .init() }
}
