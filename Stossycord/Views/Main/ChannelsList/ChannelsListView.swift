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
            ForEach(webSocketService.channels, id: \.id) { channels in
                if channels.type == 0 || channels.type == 5 {
                    NavigationLink {
                        ChannelView(webSocketService: webSocketService, currentchannelname: channels.name, currentid: channels.id)
                    } label: {
                        Text("# " + channels.name)
                            .font(.headline)
                            .foregroundColor(.primary) // Apple-like text color
                    }
                } else {
                    Text(channels.name)
                        .font(.headline)
                        .foregroundColor(.primary) // Apple-like text color
                        .disabled(true)
                }
            }
        }
        .onAppear {
            
            if webSocketService.currentguild.id != guild.id {
                
                webSocketService.currentguild = guild
                
                webSocketService.channels.removeAll()
                
                if let token = keychain.get("token") {
                    getDiscordChannels(serverId: guild.id, token: token) { channels in
                        DispatchQueue.main.async {
                            webSocketService.channels = channels
                        }
                    }
                }
            }
        }
        
    }
}
