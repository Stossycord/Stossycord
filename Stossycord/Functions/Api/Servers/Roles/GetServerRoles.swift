//
//  GetServerRoles.swift
//  Stossycord
//
//  Created by Stossy11 on 26/12/2024.
//

import Foundation


func getGuildRoles(guild: Guild, completion: @escaping ([AdvancedGuild.Role]) -> Void) {
    
    
    let url = "https://discord.com/api/v10/guilds/\(guild.id)/roles"
    var request = URLRequest(url: URL(string: url)!)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(WebSocketService.shared.token, forHTTPHeaderField: "Authorization")
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

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
            return
        } else if let data = data {
            do {
                let guilds = try JSONDecoder().decode([AdvancedGuild.Role].self, from: data)
                
                let sorted = guilds.sorted { $0.position > $1.position }
                
                DispatchQueue.main.async {
                    completion(sorted)
                }
            } catch {
                print("Error decoding JSON to get Guilds: \(error.localizedDescription), data: \(data.utf8String)")
            }
        }
    }

    task.resume()
    
    
}
