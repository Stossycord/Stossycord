//
//  StossycordApp.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI
import KeychainSwift

@main
struct StossycordApp: App {
    @StateObject var webSocketService = WebSocketService()
    let keychain = KeychainSwift()
    @State var isPresented: Bool = false
    @State var isfirst: Bool = false
    @Environment(\.scenePhase) var scenePhase
    @State var network = true
    var body: some Scene {
        WindowGroup {
            NavView(webSocketService: webSocketService)
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        if !isfirst {
                            isfirst = true
                        } else {
                            webSocketService.connect()
                            // Handle app opened
                            print("App opened")
                        }
                    case .inactive:
                        webSocketService.disconnect()
                        // Handle app going inactive
                        print("App going inactive")
                    case .background:
                        webSocketService.disconnect()
                        // Handle app closed or backgrounded
                        print("App closed or in background")
                    @unknown default:
                        break
                    }
                }
                .sheet(isPresented: $isPresented) {
                    WelcomeView(webSocketService: webSocketService)
                }
                .onAppear {
                    if let token = keychain.get("token"), !token.isEmpty {
                        webSocketService.connect()
                    } else {
                        isPresented = true
                    }
                }
                .overlay {
                    if !network {
                        VStack {
                            Text("You Are Offline")
                            Spacer()
                        }
                    }
                }
                .onChange(of: webSocketService.isNetworkAvailable) { newValue in
                    if newValue {
                        print("Network is Avalible")
                    }
                    if !newValue {
                        print("Network is Unavalible")
                    }
                    
                    network = newValue
                }
        }
    }
}
