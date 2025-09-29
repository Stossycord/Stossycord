//
//  ChannelsListView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation
import KeychainSwift

struct ChannelsListView: View {
    @State var guild: Guild
    let keychain = KeychainSwift()
    @StateObject var webSocketService: WebSocketService
    
    var body: some View {
        NavigationView {
            List {
                // Check if there are any channels to display
                if webSocketService.channels.isEmpty {
                    Text("No channels available.")
                        .foregroundColor(.gray)
                } else {
                    // Iterate over the categories
                    ForEach(webSocketService.channels, id: \.id) { Category in
                        if !Category.name.isEmpty {
                            Section(header: Text(Category.name)
                                .font(.title)
                                .foregroundColor(.primary)
                                .padding(.top)) {
                                    
                                    // Iterate over the channels within each Category
                                    ForEach(Category.channels, id: \.id) { channel in
                                        if channel.type == 0 || channel.type == 5 {
                                            NavigationLink {
                                                ChannelView(webSocketService: webSocketService, currentchannelname: channel.name, currentid: channel.id, currentGuild: guild)
                                            } label: {
                                                Text("# " + channel.name)
                                                    .font(.headline)
                                                    .foregroundColor(.primary) // Apple-like text color
                                            }
                                        } else {
                                            Text(channel.name)
                                                .font(.headline)
                                                .foregroundColor(.primary) // Apple-like text color
                                                .disabled(true)
                                        }
                                    }
                                }
                        } else {
                            Section {
                                ForEach(Category.channels, id: \.id) { channel in
                                    if channel.type == 0 || channel.type == 5 {
                                        NavigationLink {
                                            ChannelView(webSocketService: webSocketService, currentchannelname: channel.name, currentid: channel.id, currentGuild: guild)
                                        } label: {
                                            Text("# " + channel.name)
                                                .font(.headline)
                                                .foregroundColor(.primary) // Apple-like text color
                                        }
                                    } else {
                                        Text(channel.name)
                                            .font(.headline)
                                            .foregroundColor(.primary) // Apple-like text color
                                            .disabled(true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if webSocketService.currentguild.id != guild.id {
                webSocketService.currentguild = guild
                webSocketService.channels.removeAll()
                
                if let token = keychain.get("token") {
                    channels(token: token)
                    webSocketService.requestGuildMembers(guildID: guild.id)
                    
                    Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { timer in
                        getGuildRoles(guild: guild) { roles in
                            DispatchQueue.main.async {
                                webSocketService.currentroles = roles
                            }
                        }
                    }
                }
            }
        }
    }
    
    func channels(token: String) {
        getDiscordChannels(serverId: guild.id, token: token) { channels in
            // Filter for both text channels and categories
            let recievedChannels = channels.filter { $0.type == 0 || $0.type == 5 }
            
            // Get categories
            let recievedcategories = channels.filter { $0.type == 4 }
            
            var categories: [Category] = []
            
            recievedcategories.forEach { headin in
                // Get channels that belong to this category
                let channelsForCategory = recievedChannels.filter { $0.parent_id == headin.id }
                
                let Category = Category(id: headin.id, name: headin.name, type: headin.type, position: headin.position, channels: channelsForCategory)
                categories.append(Category)
            }
            
            
            
            let channelswithoutCategories = recievedChannels.filter { $0.parent_id == nil }
            
            
            let noChannelCategory = Category(id: "0", name: "", type: 4, position: 0, channels: channelswithoutCategories)
            
            
            
            // Sort categories by position if available
            var sortedcategories = categories.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            
            sortedcategories.insert(noChannelCategory, at: 0)
            
            DispatchQueue.main.async {
                webSocketService.channels = sortedcategories
            }
        }
    }
}
