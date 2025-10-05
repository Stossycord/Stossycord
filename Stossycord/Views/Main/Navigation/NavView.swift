//
//  NavView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI

enum Tabs: Hashable {
    case home, dm, settings, search
}

struct NavView: View {
    @StateObject var webSocketService: WebSocketService
    @State private var selectedTab: Tabs = .home
    
    var body: some View {
        #if os(macOS)
        NavigationView {
            legacyTabView()
        }
    #else
        iosTabView()
    #endif
    }
}

#if os(iOS)
extension NavView {
    @ViewBuilder
    private func iosTabView() -> some View {
        if #available(iOS 18.0, *) {
            modernTabView()
        } else {
            legacyTabView()
        }
    }
    
    @ViewBuilder
    @available(iOS 18.0, *)
    private func modernTabView() -> some View {
        let tabView = TabView(selection: $selectedTab) {
            Tab("Servers", systemImage: "house", value: Tabs.home) {
                ServerView(webSocketService: webSocketService)
            }
            
            Tab("DMs", systemImage: "envelope", value: Tabs.dm) {
                DMsView(webSocketService: webSocketService)
            }
            
            Tab("Settings", systemImage: "gear", value: Tabs.settings) {
                SettingsView()
            }
            
            Tab(value: Tabs.search, role: .search) {
                SearchView(webSocketService: webSocketService)
            }
        }
        .onChange(of: selectedTab, perform: handleTabChange)
        
        if #available(iOS 26.0, *) {
            tabView.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabView
        }
    }
    
    private func handleTabChange(_ tab: Tabs) {
        if tab == .search {
            print("search")
        }
    }
}
#endif

extension NavView {
    @ViewBuilder
    private func legacyTabView() -> some View {
        TabView(selection: $selectedTab) {
            ServerView(webSocketService: webSocketService)
                .tabItem {
                    Label("Servers", systemImage: "house")
                }
                .tag(Tabs.home)
            DMsView(webSocketService: webSocketService)
                .tabItem {
                    Label("DMs", systemImage: "envelope")
                }
                .tag(Tabs.dm)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tabs.settings)
        }
    }
}
