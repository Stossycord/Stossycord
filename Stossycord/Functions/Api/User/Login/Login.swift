//
//  Login.swift
//  Stossycord
//
//  Created by Stossy11 on 20/4/2026.
//

import Foundation

extension String: @retroactive Error {
    public var localizedDescription: String {
        self
    }
}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? {
        self
    }
}

class Login: DiscordRequest<LoginResponse>, APIRequest {
    typealias Response = LoginResponse
    
    var endpoint: String = "auth/login"
    var method: String = "POST"
    
    var email: String
    var password: String
    var captchaKey: String?
    
    init(email: String, password: String, captchaKey: String? = nil) {
        self.email = email
        self.password = password
        self.captchaKey = captchaKey
    }
    
    func makeBody() -> Data? {
        var body: [String: Any] = [
            "login": email,
            "password": password,
            "undelete": false,
            "login_source": nil as Any? ?? NSNull(),
            "gift_code_sku_id": nil as Any? ?? NSNull()
        ]
        if let captcha = captchaKey {
            body["captcha_key"] = captcha
        }
        return try? JSONSerialization.data(withJSONObject: body)
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        return DiscordAPI.makeUrlRequest(
            url: DiscordAPI.shared.makeAPIUrl(endpoint),
            authenticated: false,
            includeBrowserContextHeaders: false
        )
    }
}

class MFALogin: DiscordRequest<LoginResponse>, APIRequest {
    typealias Response = LoginResponse
    
    var endpoint: String = "auth/mfa/totp"
    var method: String = "POST"
    
    var code: String
    var ticket: String
    
    init(code: String, ticket: String) {
        self.code = code
        self.ticket = ticket
    }
    
    func makeBody() -> Data? {
        let body: [String: Any] = [
            "code": code,
            "ticket": ticket,
            "login_source": NSNull(),
            "gift_code_sku_id": NSNull()
        ]
        return try? JSONSerialization.data(withJSONObject: body)
    }
    
    func handleArgs(_ args: [Any?]) throws -> URLRequest? {
        return DiscordAPI.makeUrlRequest(
            url: DiscordAPI.shared.makeAPIUrl(endpoint),
            authenticated: false,
            includeBrowserContextHeaders: false
        )
    }
}

class Logout: DiscordRequest<String>, APIRequest {
    typealias Response = String

    var endpoint: String = "auth/logout"
    var method: String = "POST"

    var responseHandler: ((Data, URLResponse) -> String)? {
        { data, _ in String(data: data, encoding: .utf8) ?? "" }
    }

    func makeBody() -> Data? {
        let body: [String: Any] = [
            "provider": NSNull(),
            "voip_provider": NSNull()
        ]
        return try? JSONSerialization.data(withJSONObject: body)
    }
}

struct LoginResponse: Decodable {
    let token: String?
    let mfa: Bool?
    let ticket: String?
    let sms: Bool?
    let backup: Bool?
    let totp: Bool?
    let hasWebAuthn: Bool
    let mfaMethods: [MFAMethod]?
    let captchaKey: [String]?
    let captchaSitekey: String?
    let message: String?
    let errors: [String: LoginFieldError]?
    
    enum CodingKeys: String, CodingKey {
        case token, mfa, ticket, message, errors, sms, backup, totp, webauthn
        case mfaMethods = "mfa_methods"
        case captchaKey = "captcha_key"
        case captchaSitekey = "captcha_sitekey"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        mfa = try container.decodeIfPresent(Bool.self, forKey: .mfa)
        ticket = try container.decodeIfPresent(String.self, forKey: .ticket)
        sms = try container.decodeIfPresent(Bool.self, forKey: .sms)
        backup = try container.decodeIfPresent(Bool.self, forKey: .backup)
        totp = try container.decodeIfPresent(Bool.self, forKey: .totp)
        mfaMethods = try container.decodeIfPresent([MFAMethod].self, forKey: .mfaMethods)
        captchaKey = try container.decodeIfPresent([String].self, forKey: .captchaKey)
        captchaSitekey = try container.decodeIfPresent(String.self, forKey: .captchaSitekey)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        errors = try container.decodeIfPresent([String: LoginFieldError].self, forKey: .errors)
        hasWebAuthn = container.contains(.webauthn) && ((try? container.decodeNil(forKey: .webauthn)) == false)
    }

    var displayErrorMessage: String {
        if let validationMessage {
            return validationMessage
        }
        return message ?? "Login failed"
    }

    private var validationMessage: String? {
        let messages = errors?.values
            .flatMap { $0.errors }
            .compactMap(\.message) ?? []

        let uniqueMessages = messages.reduce(into: [String]()) { result, message in
            if !result.contains(message) {
                result.append(message)
            }
        }

        return uniqueMessages.isEmpty ? nil : uniqueMessages.joined(separator: "\n")
    }

    var requiresCaptcha: Bool {
        captchaKey?.contains("captcha-required") ?? false
    }

    var requiresMFA: Bool {
        mfa == true && ticket != nil
    }

    var mfaChallenge: LoginMFAChallenge? {
        guard requiresMFA, let ticket else { return nil }

        var methods = Set<LoginMFAMethod>()
        if totp == true { methods.insert(.totp) }
        if backup == true { methods.insert(.backup) }
        if sms == true { methods.insert(.sms) }
        if hasWebAuthn { methods.insert(.webauthn) }

        for method in mfaMethods ?? [] {
            if let loginMethod = LoginMFAMethod(rawValue: method.type) {
                methods.insert(loginMethod)
            }
        }

        if methods.isEmpty {
            methods.insert(.totp)
        }

        return LoginMFAChallenge(ticket: ticket, methods: methods)
    }
}

struct LoginFieldError: Decodable {
    let errors: [LoginValidationError]

    enum CodingKeys: String, CodingKey {
        case errors = "_errors"
    }
}

struct LoginValidationError: Decodable {
    let code: String?
    let message: String?
}

enum LoginMFAMethod: String, Decodable, Equatable, Hashable {
    case totp
    case backup
    case sms
    case webauthn
}

struct LoginMFAChallenge: Equatable {
    let ticket: String
    let methods: Set<LoginMFAMethod>

    var supportsCode: Bool {
        methods.contains(.totp) || methods.contains(.backup)
    }

    var hasUnsupportedPasskey: Bool {
        methods.contains(.webauthn)
    }

    var unsupportedPasskeyMessage: String {
        if supportsCode {
            return "Passkey MFA can't be completed in Stossycord because iOS only allows passkeys for apps associated with discord.com. Use an authenticator app or backup code instead."
        }
        return "Passkey MFA can't be completed in Stossycord because iOS only allows passkeys for apps associated with discord.com. Add an authenticator app, use a backup code, or log in through Discord."
    }
    
    var unsupportedCodeMessage: String {
        "This account requires an MFA method Stossycord can't complete here. Use an authenticator app, a backup code, or log in through Discord."
    }
}

struct MFAMethod: Decodable, Equatable {
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let type = try? container.decode(String.self) {
            self.type = type
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
    }
}

extension DiscordRequest {
    static func login(email: String, password: String, captchaKey: String? = nil) -> Login {
        .init(email: email, password: password, captchaKey: captchaKey)
    }

    static func mfaLogin(code: String, ticket: String) -> MFALogin {
        .init(code: code, ticket: ticket)
    }

    static var logout: Logout {
        .init()
    }
}
