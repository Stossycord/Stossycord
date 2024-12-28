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
    @State var showPopover = false
    @State var guildID = ""
    
    var body: some View {
        PlatformSpecificView {
            List {
                ForEach(filteredGuilds, id: \.id) { guild in
                    #if os(macOS)
                    NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService)) {
                        HStack {
                            GuildIconView(iconURL: guild.iconUrl)
                            VStack(alignment: .leading) {
                                Text(guild.name)
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    #else
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService)) {
                            HStack {
                                GuildIconView(iconURL: guild.iconUrl)
                                VStack(alignment: .leading) {
                                    Text(guild.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        NavigationLink(destination: ChannelsListView(guild: guild, webSocketService: webSocketService).toolbar(.hidden, for: .tabBar)) {
                            HStack {
                                GuildIconView(iconURL: guild.iconUrl)
                                VStack(alignment: .leading) {
                                    Text(guild.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    #endif
                }
                // .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
            .onAppear {
                webSocketService.currentguild = Guild(id: "", name: "", icon: "")
            }
            .searchable(text: $searchTerm, prompt: Text("Search for a server"))
            .navigationTitle("Servers")
            #if !os(macOS)
            .toolbar(.visible, for: .tabBar)
            #endif
        }
    }
    
    // Filter guilds based on the search term
    private var filteredGuilds: [Guild] {
        webSocketService.Guilds.filter { guild in
            searchTerm.isEmpty || guild.name.localizedCaseInsensitiveContains(searchTerm)
        }
    }
}



@ViewBuilder
func PlatformSpecificView<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
    #if os(macOS)
    VStack {
        content()
    }
    #else
    NavigationView {
        content()
    }
    #endif
}
