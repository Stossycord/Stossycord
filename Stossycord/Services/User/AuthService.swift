//
//  AuthService.swift
//  Stossycord
//
//  Created by Stossy11 on 20/4/2026.
//

import Foundation

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var state: AuthState = .idle
    
    enum AuthState: Equatable {
        case idle
        case loading
        case needsCaptcha(sitekey: String)
        case needsMFA(LoginMFAChallenge)
        case success(token: String)
        case failure(String)
    }
    
    private var pendingEmail: String = ""
    private var pendingPassword: String = ""
    
    func login(email: String, password: String, captchaKey: String? = nil) async {
        state = .loading
        pendingEmail = email
        pendingPassword = password
        
        do {
            let response = try await DiscordAPI.shared.makeRequest(.login(email: email, password: password, captchaKey: captchaKey))
            await handleResponse(response)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
    
    func submitMFA(code: String, ticket: String) async {
        state = .loading
        do {
            let response = try await DiscordAPI.shared.makeRequest(.mfaLogin(code: code, ticket: ticket))
            await handleResponse(response)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
    
    func retryWithCaptcha(token: String) async {
        await login(email: pendingEmail, password: pendingPassword, captchaKey: token)
    }
    
    func completeLogin(token: String) {
        CurrentUserService.shared.token = token
        state = .success(token: token)
    }
    
    private func handleResponse(_ response: LoginResponse) async {
        if let token = response.token {
            completeLogin(token: token)
        } else if response.requiresCaptcha, let sitekey = response.captchaSitekey {
            state = .needsCaptcha(sitekey: sitekey)
        } else if let challenge = response.mfaChallenge {
            state = .needsMFA(challenge)
        } else {
            state = .failure(response.displayErrorMessage)
        }
    }
}
