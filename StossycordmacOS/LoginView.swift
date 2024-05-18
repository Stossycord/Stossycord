//
//  LoginView.swift
//  Stossy11DIscord
//
//  Created by Hristos Sfikas on 9/5/2024.
//

import Foundation
import SwiftUI
import KeychainSwift

struct LoginView: View {
    @ObservedObject var webSocketClient: WebSocketClient
    @State var Username = ""
    @State var Password = ""
    @State var showingPopover = false
    @State private var token: String = ""
    @State private var ticket = ""
    @State private var code = ""
    @Environment(\.dismiss) var dismiss
    let keychain = KeychainSwift()
    
    var body: some View {
        VStack {
            Text("")
            Text("Welcome to StossyCord it is a custom Discord Client")
                .font(.title)
            Text("Login to Discord")
                .padding()
            TextField("Email", text: $Username)
                        .padding()
            SecureField("Password", text: $Password)
                        .padding()
            Button("Login") {
                sendPostRequest2(username: Username, password: Password) { user in
                    print("\(user.mfa)" + " " + user.ticket)
                    self.showingPopover = user.mfa
                    self.ticket = user.ticket
                }
            }
        }
        .popover(isPresented: $showingPopover) {
            TextField("Authentication Code", text: $code)
            Button("Submit") {
                if code.isEmpty != true {
                    print(self.code)
                    sendNewPostRequest(code: self.code, ticket: self.ticket) { user in
                        self.token = user.token
                        self.keychain.set(self.token, forKey: "token")
                        dismiss()
                        webSocketClient.getcurrentchannel(input: "", guild: "")
                    }
                }
            }
        }
    }
}

struct User: Codable {
    let user_id: String
    let mfa: Bool
    let sms: Bool
    let ticket: String
    let backup: Bool
    let totp: Bool
    let webauthn: Bool?
}

struct Product: Codable {
    let token: String
}

func sendPostRequest2(username: String, password: String, completion: @escaping (User) -> Void) {
    let url = URL(string: "https://discord.com/api/v9/auth/login")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    // Headers
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("*/*", forHTTPHeaderField: "Accept")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("https://discord.com/login", forHTTPHeaderField: "Referer")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")


    // JSON Body
    let json: [String: Any] = ["login": "\(username)", "password": "\(password)", "undelete": false, "login_source": NSNull(), "gift_code_sku_id": NSNull()]
    request.httpBody = try? JSONSerialization.data(withJSONObject: json)

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            do {
                let decoder = JSONDecoder()
                let user = try decoder.decode(User.self, from: data)
                DispatchQueue.main.async {
                    completion(user)
                }
            } catch {
                let str = String(data: data, encoding: .utf8)
                print(str)
                print("Error decoding JSON: \(error)")
            }
        }
    }

    task.resume()
}

func sendNewPostRequest(code: String, ticket: String, completion: @escaping (Product) -> Void) {
    let url = URL(string: "https://discord.com/api/v9/auth/mfa/totp")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    // Headers
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("*/*", forHTTPHeaderField: "Accept")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("https://discord.com/login", forHTTPHeaderField: "Referer")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue("Australia/Sydney", forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue("eyJvcyI6Ik1hYyBPUyBYIiwiYnJvd3NlciI6IlNhZmFyaSIsImRldmljZSI6IiIsInN5c3RlbV9sb2NhbGUiOiJlbi1BVSIsImJyb3dzZXJfdXNlcl9hZ2VudCI6Ik1vemlsbGEvNS4wIChNYWNpbnRvc2g7IEludGVsIE1hYyBPUyBYIDEwXzE1XzcpIEFwcGxlV2ViS2l0LzYwNS4xLjE1IChLSFRNTCwgbGlrZSBHZWNrbykgVmVyc2lvbi8xNy40IFNhZmFyaS82MDUuMS4xNSIsImJyb3dzZXJfdmVyc2lvbiI6IjE3LjQiLCJvc192ZXJzaW9uIjoiMTAuMTUuNyIsInJlZmVycmVyIjoiIiwicmVmZXJyaW5nX2RvbWFpbiI6IiIsInJlZmVycmVyX2N1cnJlbnQiOiIiLCJyZWZlcnJpbmdfZG9tYWluX2N1cnJlbnQiOiIiLCJyZWxlYXNlX2NoYW5uZWwiOiJzdGFibGUiLCJjbGllbnRfYnVpbGRfbnVtYmVyIjoyOTE1MDcsImNsaWVudF9ldmVudF9zb3VyY2UiOm51bGwsImRlc2lnbl9pZCI6MH0=", forHTTPHeaderField: "X-Super-Properties")

    // JSON Body
    let json: [String: Any] = ["code": code, "ticket": ticket, "login_source": NSNull(), "gift_code_sku_id": NSNull()]
    request.httpBody = try? JSONSerialization.data(withJSONObject: json)

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            do {
                let decoder = JSONDecoder()
                let user = try decoder.decode(Product.self, from: data)
                DispatchQueue.main.async {
                    completion(user)
                }
            } catch {
                let str = String(data: data, encoding: .utf8)
                print(str)
                print("Error decoding JSON: \(error)")
            }
        }
    }
    task.resume()
}
