//
//  ServerViewStack.swift
//  Stossycord
//
//  Created by Stossy11 on 15/1/2026.
//

import Foundation
import SwiftUI

struct ServerViewStack: View {
    @State var guild: Guild? = nil
    @EnvironmentObject var userSession: CurrentUserService
    @State var justChanged = true
    @AppStorage("welcomeBack") var welcomeBack: Bool = false
    var body: some View {
        if UIDevice.current.userInterfaceIdiom != .pad {
            ServerView(guild: $guild, webSocketService: .shared)
        } else {
            HStack {
                ServerView(guild: $guild, webSocketService: .shared)
                    .frame(maxWidth: 80)
                
                
                Divider().frame(width: 1)
                    .ignoresSafeArea(edges: .all)
                
                if let guild = guild {
                    ChannelsListView(guild: guild, webSocketService: .shared)
                } else {
                    Spacer()
                        .overlay(alignment: .center) {
                            emptyStateView
                        }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            let user = userSession.user
            let text = user == nil ? "Welcome to Stossycord" : "Welcome, \((user?.global_name ?? user?.username) ?? "to Stossycord")!"
            
            Text(welcomeBack && justChanged ? text : text.replacingOccurrences(of: "Welcome", with: "Welcome back"))
                .font(.headline)
                .foregroundColor(.secondary)
            
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .onAppear() {
            if !welcomeBack {
                justChanged = true
                welcomeBack = true
            }
            justChanged = false
        }
    }
}
