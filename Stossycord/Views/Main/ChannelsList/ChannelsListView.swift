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
        List {
            // Check if there are any channels to display
            if webSocketService.channels.isEmpty {
                Text("No channels available.")
                    .foregroundColor(.gray)
            } else {
                // Iterate over the headings
                ForEach(webSocketService.channels, id: \.id) { heading in
                    Section(header: Text(heading.name)
                                .font(.title)
                                .foregroundColor(.primary)
                                .padding(.top)) {
                        
                        // Iterate over the channels within each heading
                        ForEach(heading.channels, id: \.id) { channel in
                            if channel.type == 0 || channel.type == 5 {
                                NavigationLink {
                                    ChannelView(webSocketService: webSocketService, currentchannelname: channel.name, currentid: channel.id)
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
        .onAppear {
            if webSocketService.currentguild.id != guild.id {
                webSocketService.currentguild = guild
                webSocketService.channels.removeAll()
                
                if let token = keychain.get("token") {
                    channels(token: token)
                }
            }
        }
    }
    
    func channels(token: String) {
        getDiscordChannels(serverId: guild.id, token: token) { channels in
            // Filter for both text channels and categories
            let recievedChannels = channels.filter { $0.type == 0 }
            
            // Get categories
            let recievedHeadings = channels.filter { $0.type == 4 }
            
            var headings: [Heading] = []
            
            recievedHeadings.forEach { headin in
                // Get channels that belong to this category
                let channelsForHeading = recievedChannels.filter { $0.parent_id == headin.id }
                
                let heading = Heading(id: headin.id, name: headin.name, type: headin.type, position: headin.position, channels: channelsForHeading)
                headings.append(heading)
            }
            
            // Sort headings by position if available
            let sortedHeadings = headings.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            
            DispatchQueue.main.async {
                webSocketService.channels = sortedHeadings
            }
        }
    }
}
