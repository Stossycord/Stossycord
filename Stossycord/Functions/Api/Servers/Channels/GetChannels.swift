//
//  GetChannels.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

func getDiscordChannels(serverId: String, token: String, completion: @escaping ([Channel]) -> Void) {
    guard let url = URL(string: "https://discord.com/api/v9/guilds/\(serverId)/channels?channel_limit=100") else {
        // print("Invalid URL")
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

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
        } else if let data = data {
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    
                    do {
                        let channels = try JSONDecoder().decode([Channel].self, from: data)
                        DispatchQueue.main.async {
                            completion(channels)
                        }
                    } catch {
                        print("Error decoding JSON: \(error)")
                    }
                }
            } catch {
                // print("Error: \(error)")
            }
        }
    }

    task.resume()
}
