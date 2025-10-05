//
//  LeaveServer.swift
//  Stossycord
//
//  Created by GitHub Copilot on 05/10/2025.
//

import Foundation

func leaveDiscordGuild(token: String, guildId: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
    guard let url = URL(string: "https://discord.com/api/v10/users/@me/guilds/\(guildId)") else {
        completion?(.failure(NSError(domain: "LeaveDiscordGuild", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid guild identifier"])))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
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

    let body: [String: Any] = ["lurking": false]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion?(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            completion?(.failure(NSError(domain: "LeaveDiscordGuild", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
            return
        }

        switch httpResponse.statusCode {
        case 200..<300:
            completion?(.success(()))
        default:
            let responseData = data ?? Data()
            let errorDescription: String
            if !responseData.isEmpty, let message = String(data: responseData, encoding: .utf8), !message.isEmpty {
                errorDescription = message
            } else {
                errorDescription = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            }
            var userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: errorDescription,
                "statusCode": httpResponse.statusCode,
                "headers": httpResponse.allHeaderFields
            ]
            if !responseData.isEmpty {
                userInfo["responseData"] = responseData
            }
            let error = NSError(domain: "LeaveDiscordGuild", code: httpResponse.statusCode, userInfo: userInfo)
            completion?(.failure(error))
        }
    }

    task.resume()
}
