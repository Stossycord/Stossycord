//
//  CurrentUser.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

func CurrentUser(token: String, completion: @escaping (User?) -> Void) {
    let url = URL(string: "https://discord.com/api/v10/users/@me")!
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
    let Country: String = CurrentDeviceInfo.shared.Country
    
    let currentTimeZone = CurrentDeviceInfo.shared.currentTimeZone
    
    let timeZoneIdentifier = currentTimeZone.identifier
    
    let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
    
    request.addValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("\(currentTimeZone)-\(Country)", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue(timeZoneIdentifier, forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue(deviceInfo.toBase64() ?? "base64", forHTTPHeaderField: "X-Super-Properties")

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            do {
                do {
                    let discordUser = try JSONDecoder().decode(User.self, from: data)
                    //print(discordUser)
                    print(String(data: data, encoding: .utf8) ?? "")
                    completion(discordUser)
                } catch {
                    print("Failed to decode JSON: \(error)")
                    completion(nil)
                }
            } catch {
                print("Error: \(error)")
                completion(nil)
            }
        }
    }

    task.resume()
}
