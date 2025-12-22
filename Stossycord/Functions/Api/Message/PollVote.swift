import Foundation

private func buildPollVoteRequest(token: String, channelId: String, messageId: String) -> URLRequest {
    let url = URL(string: "https://discord.com/api/v10/channels/\(channelId)/polls/\(messageId)/answers/@me")!
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

    let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
    let currentTimeZone = CurrentDeviceInfo.shared.currentTimeZone
    let timeZoneIdentifier = currentTimeZone.identifier
    let country = CurrentDeviceInfo.shared.Country

    request.addValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("\(currentTimeZone)-\(country)", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue(timeZoneIdentifier, forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue(deviceInfo.toBase64() ?? "base64", forHTTPHeaderField: "X-Super-Properties")

    return request
}

func updatePollVotes(token: String, channelId: String, messageId: String, answerIds: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
    var request = buildPollVoteRequest(token: token, channelId: channelId, messageId: messageId)
    let payload = ["answer_ids": answerIds]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
    } catch {
        completion(.failure(error))
        return
    }

    URLSession.shared.dataTask(with: request) { _, response, error in
        if let error = error {
            Task { @MainActor in  completion(.failure(error)) }
            return
        }

        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let error = NSError(domain: "PollVote", code: httpResponse.statusCode, userInfo: nil)
            Task { @MainActor in  completion(.failure(error)) }
            return
        }

        Task { @MainActor in  completion(.success(())) }
    }.resume()
}
