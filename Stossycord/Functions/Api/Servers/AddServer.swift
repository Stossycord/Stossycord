//
//  AddServer.swift
//  Stossycord
//
//  Created by Stossy11 on 7/11/2024.
//

import Foundation


func joinDiscordGuild(token: String, guildId: String, lurker: Bool? = nil, sessionId: String? = nil, location: String? = nil, recommendationLoadId: String? = nil, completion: @escaping (String?) -> Void) {
    let url = URL(string: "https://discord.com/api/v10/guilds/\(guildId)/members/@me")!
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
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
    
    // Prepare query parameters as JSON body
    var requestBody: [String: Any] = [:]
    if let lurker = lurker {
        requestBody["lurker"] = lurker
    }
    if let sessionId = sessionId {
        requestBody["session_id"] = sessionId
    } else {
        requestBody["lurker"] = false
    }
    if let location = location {
        requestBody["location"] = location
    }
    if let recommendationLoadId = recommendationLoadId {
        requestBody["recommendation_load_id"] = recommendationLoadId
    }
    
    // Encode request body to JSON
    if !requestBody.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) {
        request.httpBody = jsonData
    }
    
    print(requestBody)

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
            return
        } else if let data = data {
            do {
                completion(String(data: data, encoding: .utf8))
            } catch {
                print("Error decoding JSON: \(error)")
                completion(nil)
            }
        } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
            // Successfully joined but no data returned
            completion(nil)
        }
    }

    task.resume()
}

