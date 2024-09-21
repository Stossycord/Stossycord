//
//  GetDMs.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import Foundation

func getDiscordDMs(token: String, completion: @escaping ([DMs]) -> Void) {
    guard let url = URL(string: "https://discord.com/api/v9/users/@me/channels") else {
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
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            // print("Error: \(error)")
        } else if let data = data {
            do {
                
                
                var channels: [DMs] = []
                
                channels = try JSONDecoder().decode([DMs].self, from: data)

                channels.sort { $0.position > $1.position }
                DispatchQueue.main.async {
                    completion(channels)
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }

    task.resume()
}
