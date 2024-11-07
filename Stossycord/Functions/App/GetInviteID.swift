//
//  GetInviteID.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//

import Foundation

func GetInviteId(from url: String) -> String? {
    let regexPattern = #"https?://(www\.)?(discord\.gg|discord\.com/invite)/([a-zA-Z0-9]+)"#
    
    do {
        let regex = try NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: url.utf16.count)
        
        if let match = regex.firstMatch(in: url, options: [], range: range) {
            // Capture group 3 contains the invite ID
            if let inviteIDRange = Range(match.range(at: 3), in: url) {
                return String(url[inviteIDRange])
            }
        }
    } catch {
        print("Invalid regex: \(error)")
    }
    
    return nil
}
