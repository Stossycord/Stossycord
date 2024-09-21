//
//  WelcomeView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var webSocketService: WebSocketService
    @State var login = false
    var body: some View {
        if login {
            LoginView(webSocketService: webSocketService)
                .padding()
        } else {
            VStack {
                Text("Welcome to\nStossycord")
                    .font(.largeTitle)
                    .bold()
                
                Text("A Native Discord Client for iOS")
                    .font(.title2)
                    .padding()
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    login = true
                }) {
                    Text("Login")
                }
            }
            .interactiveDismissDisabled()
        }
    }
}


