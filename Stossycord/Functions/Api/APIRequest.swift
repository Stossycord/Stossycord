//
//  APIRequest.swift
//  Stossycord
//
//  Created by Stossy11 on 14/1/2026.
//

import Foundation

public protocol APIRequest {
    associatedtype Response: Decodable

    var endpoint: String { get }
    var method: String { get }
    var headers: [String: String] { get }

    var responseHandler: ((Data, URLResponse) -> Response)? { get }

    func makeBody() -> Data?

    func handleArgs(_ args: [Any?]) throws -> URLRequest?
}

extension APIRequest {
    var type: Self.Response.Type { Response.self }

    var headers: [String : String] { [:] }

    var responseHandler: ((Data, URLResponse) -> Response)? { return nil }

    func makeBody() -> Data? { return nil }

    func handleArgs(_ args: [Any?]) throws -> URLRequest? { return nil }

    func makeAPIUrl(_ endpoint: String) -> URL { URL(string: "https://discord.com/api/v9/" + endpoint)! }

    func makeUrlRequest(
        url: URL,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 60.0,
        json: Bool = true,
        authenticated: Bool = true,
        includeBrowserContextHeaders: Bool = true
    ) -> URLRequest {
        DiscordAPI.makeUrlRequest(
            url: url,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval,
            json: json,
            authenticated: authenticated,
            includeBrowserContextHeaders: includeBrowserContextHeaders
        )
    }
}

public class DiscordRequest<Response: Decodable> {
    public func body() -> (any APIRequest)? {
        return self as? any APIRequest
    }
}
