//
//  GetChannels.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

class GetChannels: DiscordRequest<[Channel]>, APIRequest {
    typealias Response = [Channel]
    
    var endpoint: String = ""
    var method: String = "GET"
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let serverId = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        return makeUrlRequest(url: makeAPIUrl("guilds/\(serverId)/channels?channel_limit=100"))
    }
}

extension DiscordRequest {
    static var channels: GetChannels { .init() }
}

@available(iOS, introduced: 8.0, deprecated: 16.0, message: "Use system Locale.region on iOS 16+")
extension Locale {
    struct CompatRegion {
        let identifier: String
    }
    
    var region: CompatRegion? {
        struct Region {
            let identifier: String
        }
        
        if let regionCode = self.regionCode {
            return CompatRegion(identifier: regionCode)
        }
        return nil
    }
}
