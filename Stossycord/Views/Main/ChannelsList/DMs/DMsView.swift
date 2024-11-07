//
//  DMsView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation
import KeychainSwift

struct DMsView: View {
    let keychain = KeychainSwift()
    @StateObject var webSocketService: WebSocketService
    var body: some View {
        NavigationView {
            List {
                ForEach(webSocketService.dms, id: \.id) { channels in
                    if channels.type == 1 {
                        NavigationLink {
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                ChannelView(webSocketService: webSocketService, currentchannelname: "@" + (channels.recipients?.first!.username)!, currentid: channels.id)
                            } else {
                                ChannelView(webSocketService: webSocketService, currentchannelname: "@" + (channels.recipients?.first!.username)!, currentid: channels.id).toolbar(.hidden, for: .tabBar)
                            }
                        } label: {
                            HStack {
                                if let avatar = channels.recipients?.first?.avatar {
                                    AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(channels.recipients!.first!.id)/\(avatar).png")) { image in
                                        image.resizable()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        ProgressView()
                                    }
                                } else {
                                    AsyncImage(url: URL(string: "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png")) { image in
                                        image.resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .padding(7)
                                            .background(Circle().fill(Color.blue))
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        ProgressView()
                                    }
                                }
                                Text((channels.recipients!.first!.global_name) ?? (channels.recipients!.first!.username))
                                    .font(.headline)
                                    .foregroundColor(.primary) // Apple-like text color
                            }
                        }
                    } else if channels.type == 3 {
                        let otherrecipientNames = channels.recipients?.prefix(3).map { "@\($0.global_name ?? $0.username)" } ?? []
                        let namesString2 = otherrecipientNames.joined(separator: ", ")
                        
                        NavigationLink {
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                ChannelView(webSocketService: webSocketService, currentchannelname: namesString2, currentid: channels.id)
                            } else {
                                ChannelView(webSocketService: webSocketService, currentchannelname: namesString2, currentid: channels.id).toolbar(.hidden, for: .tabBar)
                            }
                        } label: {
                            let recipientNames = channels.recipients?.prefix(3).map { $0.global_name ?? $0.username } ?? []
                            let namesString = recipientNames.joined(separator: ", ")
                            Text("Group Chat \(namesString)\(channels.recipients!.count > 3 ? ", +\(channels.recipients!.count - 3)" : ""))")
                                .font(.headline)
                                .foregroundColor(.primary) // Apple-like text color
                        }
                    }
                }
            }
        }
        .onAppear {
            guard let token = keychain.get("token") else { return }
            getDiscordDMs(token: token) { items in
                webSocketService.dms = items
            }
        }
        
    }
}



