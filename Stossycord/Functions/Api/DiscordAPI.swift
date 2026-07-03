//
//  DiscordAPI.swift
//  Stossycord
//
//  Created by Stossy11 on 14/1/2026.
//

import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry var api: DiscordAPI = .shared
}

public final class DiscordAPI {
    static var shared = DiscordAPI()
    private init() {}

    private static let cachedHeaders: [String: String] = {
        let tz = TimeZone.current
        let country = Locale.current.region?.identifier ?? "US"
        let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
        return [
            "Accept-Encoding":   "gzip, deflate, br",
            "Accept-Language":   "en-AU,en;q=0.9",
            "Connection":        "keep-alive",
            "Origin":            "https://discord.com",
            "Sec-Fetch-Dest":    "empty",
            "Sec-Fetch-Mode":    "cors",
            "Sec-Fetch-Site":    "same-origin",
            "User-Agent":        deviceInfo.browser_user_agent,
            "X-Debug-Options":   "bugReporterEnabled",
            "X-Discord-Locale":  "\(tz)-\(country)",
            "X-Discord-Timezone": tz.identifier,
            "X-Super-Properties": deviceInfo.toBase64() ?? "base64",
        ]
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldUsePipelining = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    func makeAPIUrl(_ endpoint: String) -> URL {
        URL(string: "https://discord.com/api/v9/" + endpoint)!
    }

    @discardableResult
    public func makeRequest<T: DiscordRequest<R>, R: Decodable>(
        _ requestClass: T,
        args: [Any?] = []
    ) async throws -> R {
        guard let apiRequest = requestClass.body() else {
            throw DiscordAPIError.invalidRequest
        }

        var request = try apiRequest.handleArgs(args)
            ?? Self.makeUrlRequest(url: makeAPIUrl(apiRequest.endpoint))

        request.httpMethod = apiRequest.method

        if let body = apiRequest.makeBody() {
            request.httpBody = body
        }

        for (key, value) in apiRequest.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           (httpResponse.statusCode == 401 || httpResponse.statusCode == 403),
           request.value(forHTTPHeaderField: "Authorization")?.isEmpty == false {
            throw DiscordAPIError.authenticationFailed(statusCode: httpResponse.statusCode)
        }

        if let responseHandler = apiRequest.responseHandler {
            return responseHandler(data, response) as! R
        }

        return try Self.decode(R.self, from: data)
    }

    private static func decode<R: Decodable>(_ type: R.Type, from data: Data) throws -> R {
        if type == String.self || type == String?.self {
            let str = String(data: data, encoding: .utf8) ?? ""
            if let result = str as? R { return result }
        }
        return try JSONDecoder().decode(type, from: data)
    }

    public static func makeUrlRequest(
        url: URL,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 60,
        json: Bool = true,
        authenticated: Bool = true,
        includeBrowserContextHeaders: Bool = true
    ) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)

        if json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let token = CurrentUserService.shared.token
        if authenticated && !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        for (key, value) in cachedHeaders {
            if !includeBrowserContextHeaders && Self.browserContextHeaders.contains(key) {
                continue
            }
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private static let browserContextHeaders: Set<String> = [
        "Connection",
        "Origin",
        "Sec-Fetch-Dest",
        "Sec-Fetch-Mode",
        "Sec-Fetch-Site"
    ]
}

enum DiscordAPIError: LocalizedError {
    case invalidRequest
    case authenticationFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest: "Could not construct a valid API request."
        case .authenticationFailed(let statusCode): "Discord rejected the current session. (HTTP \(statusCode))"
        }
    }
}
