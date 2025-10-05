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
    @AppStorage("useDiscordFolders") private var useDiscordFolders: Bool = false
    @State private var expandedFolders: Set<String> = []
    
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
    
    @ViewBuilder
    private func content() -> some View {
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
    
    // MARK: - Components
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search servers", text: $searchTerm)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchTerm.isEmpty {
                Button(action: { searchTerm = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if useDiscordFolders {
                    ForEach(Array(organizedContent.enumerated()), id: \.element.id) { index, item in
                        switch item.type {
                        case .folder(let folder):
                            FolderView(folder: folder, guilds: item.guilds, isExpanded: expandedFolders.contains(item.id)) {
                                if expandedFolders.contains(item.id) {
                                    expandedFolders.remove(item.id)
                                } else {
                                    expandedFolders.insert(item.id)
                                }
                            }
                        case .guild:
                            if let guild = item.guilds.first {
                                NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService)) {
                                    ServerRow(guild: guild)
                                }
                                .buttonStyle(ServerRowButtonStyle())
                            }
                        }
                    }
                } else {
                    ForEach(filteredGuilds, id: \.id) { guild in
                        NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService)) {
                            ServerRow(guild: guild)
                        }
                        .buttonStyle(ServerRowButtonStyle())
                    }
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
    
    private var organizedContent: [ContentItem] {
        guard let guildFolders = webSocketService.userSettings?.guildFolders else {
            return filteredGuilds.map { ContentItem(id: $0.id, type: .guild, guilds: [$0]) }
        }
        
        var items: [ContentItem] = []
        var processedGuildIds: Set<String> = []
        
        for folder in guildFolders {
            let folderGuilds = folder.guildIds.compactMap { guildId in
                filteredGuilds.first { $0.id == guildId }
            }
            
            if !folderGuilds.isEmpty {
                if folder.id == nil && folderGuilds.count == 1 {
                    items.append(ContentItem(id: folderGuilds[0].id, type: .guild, guilds: folderGuilds))
                } else if folder.id != nil {
                    let folderId = String(folder.id ?? 0)
                    items.append(ContentItem(id: folderId, type: .folder(folder), guilds: folderGuilds))
                }
                
                folderGuilds.forEach { processedGuildIds.insert($0.id) }
            }
        }
        
        let unorganizedGuilds = filteredGuilds.filter { !processedGuildIds.contains($0.id) }
        unorganizedGuilds.forEach { guild in
            items.append(ContentItem(id: guild.id, type: .guild, guilds: [guild]))
        }
        
        return items
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


