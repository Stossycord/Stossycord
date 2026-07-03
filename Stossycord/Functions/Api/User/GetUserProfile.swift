import Foundation

class GetUserProfile: DiscordRequest<UserProfile>, APIRequest {
    typealias Response = UserProfile
    
    var endpoint: String = "users/@me"
    var method: String = "GET"
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let userId = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        return DiscordAPI.makeUrlRequest(url: makeAPIUrl("users/\(userId)/profile?with_mutual_guilds=true&with_mutual_friends=true"))
    }
}

class GetBasicUserInfo: DiscordRequest<User>, APIRequest {
    typealias Response = User
    
    var endpoint: String = "users/@me"
    var method: String = "GET"
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let userId = args.first as? String else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        return makeUrlRequest(url: makeAPIUrl("users/\(userId)"))
    }
}

class UpdateUserProfile: DiscordRequest<String>, APIRequest {
    typealias Response = String
    
    var endpoint: String = "users/@me/profile"
    var method: String = "PATCH"
    
    var responseHandler: ((Data, URLResponse) -> String)? {
        { data, _ in String(data: data, encoding: .utf8) ?? "" }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        let bio = args[safe: 0] as? String
        let pronouns = args[safe: 1] as? String
        
        var payload: [String: Any] = [:]
        payload["bio"] = bio ?? ""
        payload["pronouns"] = pronouns ?? ""
        
        var request = makeUrlRequest(url: makeAPIUrl(endpoint))
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}

class UpdateCurrentUserInfo: DiscordRequest<String>, APIRequest {
    typealias Response = String
    
    var endpoint: String = "users/@me"
    var method: String = "PATCH"
    
    var responseHandler: ((Data, URLResponse) -> String)? {
        { data, _ in String(data: data, encoding: .utf8) ?? "" }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        let displayName = args.first as? String
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        var request = makeUrlRequest(url: makeAPIUrl(endpoint))
        if trimmedName.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "global_name": NSNull()
            ])
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "global_name": trimmedName
            ])
        }
        return request
    }
}

class UpdateUserSettings: DiscordRequest<UserSettings>, APIRequest {
    typealias Response = UserSettings
    
    var endpoint: String = "users/@me/settings"
    var method: String = "PATCH"
    
    var responseHandler: ((Data, URLResponse) -> UserSettings)? {
        { data, _ in
            (try? JSONDecoder().decode(UserSettings.self, from: data)) ?? UserSettings()
        }
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        guard let payload = args.first as? [String: Any] else {
            throw NSError(domain: "Invalid arguments", code: 0, userInfo: nil)
        }
        
        var request = makeUrlRequest(url: makeAPIUrl(endpoint))
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }
}

extension DiscordRequest {
    static var userProfile: GetUserProfile { .init() }
    static var basicUser: GetBasicUserInfo { .init() }
    static var updateUserProfile: UpdateUserProfile { .init() }
    static var updateCurrentUserInfo: UpdateCurrentUserInfo { .init() }
    static var updateUserSettings: UpdateUserSettings { .init() }
}
