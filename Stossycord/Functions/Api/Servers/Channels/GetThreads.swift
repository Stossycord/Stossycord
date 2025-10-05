import Foundation

private struct ActiveThreadsResponse: Codable {
    let threads: [Channel]
}

func getGuildActiveThreads(guildId: String, token: String, completion: @escaping ([Channel]) -> Void) {
    guard let url = URL(string: "https://discord.com/api/v10/guilds/\(guildId)/threads/active") else {
        completion([])
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

    let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
    let currentTimeZone = CurrentDeviceInfo.shared.currentTimeZone
    let timeZoneIdentifier = currentTimeZone.identifier
    let country = CurrentDeviceInfo.shared.Country

    request.addValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("\(currentTimeZone)-\(country)", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue(timeZoneIdentifier, forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue(deviceInfo.toBase64() ?? "base64", forHTTPHeaderField: "X-Super-Properties")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard error == nil, let data = data else {
            completion([])
            return
        }

        do {
            let decoded = try JSONDecoder().decode(ActiveThreadsResponse.self, from: data)
            completion(decoded.threads)
        } catch {
            print("Error decoding active threads: \(error)")
            completion([])
        }
    }

    task.resume()
}
