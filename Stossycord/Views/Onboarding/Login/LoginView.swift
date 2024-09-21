//
//  LoginView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI
import KeychainSwift

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @State var login = false
    @State var token = ""
    @StateObject var webSocketService: WebSocketService
    let keychain = KeychainSwift()
    var body: some View {
        VStack {
            Text("Login")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("Token", text: $token)
                .onSubmit {
                    keychain.set(token, forKey: "token")
                    
                    if !token.isEmpty {
                        dismiss()
                        webSocketService.connect()
                    }
                }
        }
        .interactiveDismissDisabled()
    }
}
