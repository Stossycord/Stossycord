//
//  ServersView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation

struct ServerView: View {
    @State private var searchTerm = ""
    @StateObject var webSocketService: WebSocketService
    
    var body: some View {
        PlatformSpecificView {
            VStack(spacing: 0) {
                // Search bar
                searchField
                
                // Server list
                serverList
                    .onAppear {
                        webSocketService.currentguild = Guild(id: "", name: "", icon: "")
                    }
            }
            .navigationTitle("Servers")
            #if !os(macOS)
            .toolbar(.visible, for: .tabBar)
            #endif
        }
    }
    
    // MARK: - Components
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search servers", text: $searchTerm)
                .font(.body)
            
            if !searchTerm.isEmpty {
                Button(action: { searchTerm = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredGuilds, id: \.id) { guild in
                    NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService)) {
                        ServerRow(guild: guild)
                    }
                    .buttonStyle(ServerRowButtonStyle())
                }
                
                if filteredGuilds.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(searchTerm.isEmpty ? "No servers available" : "No matching servers")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchTerm.isEmpty {
                Button("Clear Search") {
                    searchTerm = ""
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    // MARK: - Logic
    
    private var filteredGuilds: [Guild] {
        webSocketService.Guilds.filter { guild in
            searchTerm.isEmpty || guild.name.localizedCaseInsensitiveContains(searchTerm)
        }
    }
}

// MARK: - Supporting Views

struct ServerRow: View {
    let guild: Guild
    
    var body: some View {
        HStack(spacing: 14) {
            // Server icon
            ServerIconView(iconURL: guild.iconUrl)
            
            // Server name
            Text(guild.name)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
            
            Spacer()
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Platform-specific container view
struct PlatformSpecificView<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        #if os(macOS)
        VStack {
            content()
        }
        #else
        NavigationStack {
            content()
        }
        #endif
    }
}
