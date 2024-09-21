//
//  NavView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI

struct NavView: View {
    @StateObject var webSocketService: WebSocketService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ServerView(webSocketService: webSocketService)
                .tabItem {
                    Label("Servers", systemImage: "house")
                }
                .tag(0)
            DMsView(webSocketService: webSocketService)
                .tabItem {
                    Label("DMs", systemImage: "envelope")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}


