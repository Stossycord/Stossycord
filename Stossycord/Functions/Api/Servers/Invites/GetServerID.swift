//
//  GetServerID.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//

import Foundation

func GetServerID(token: String, inviteID: String, completion: @escaping (String?) -> Void) {
    let urlString = "https://discord.com/api/v10/invites/\(inviteID)"
    guard let url = URL(string: urlString) else {
        completion(nil)
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(token, forHTTPHeaderField: "Authorization")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")

    let currentTimeZone = TimeZone.current
    let timeZoneIdentifier = currentTimeZone.identifier
    let country = Locale.current.region?.identifier ?? "US"
    
    let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
    
    request.addValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("\(currentTimeZone)-\(country)", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue(timeZoneIdentifier, forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue(deviceInfo.toBase64() ?? "base64", forHTTPHeaderField: "X-Super-Properties")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error fetching guild ID:", error)
            completion(nil)
            return
        }
        
        guard let data = data else {
            print("No data returned.")
            completion(nil)
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let guild = json["guild"] as? [String: Any],
               let guildID = guild["id"] as? String {
                completion(guildID)
            } else {
                completion(nil)
            }
        } catch {
            print("Error parsing JSON:", error)
            completion(nil)
        }
    }
    
    task.resume()
}
