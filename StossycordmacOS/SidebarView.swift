//
//  SidebarView.swift
//  SimpleSidebarUI
//
//  Created by Justin Bush on 2021-03-03.
//
//  Reference
//  https://github.com/1998code/SwiftUI2-MacSidebar
//

import SwiftUI
import KeychainSwift

struct SidebarView: View {
    @AppStorage("ISOpened") var hasbeenopened = true
    @ObservedObject var webSocketClient: WebSocketClient
    @State var guilds: [(name: String, id: String, icon: String?)] = []
    @State var token = ""
    @State var username = ""
    @State var searchTerm = ""
    let keychain = KeychainSwift()
    var body: some View {
        NavigationView {
            Text("")
                .font(.title)
                .onTapGesture {
                    hasbeenopened = true
                }
                .onAppear() {
                    // let keychain = KeychainSwift()
                    token = keychain.get("token") ?? ""
                    if token == "" {
                        hasbeenopened = true
                    }
                    webSocketClient.getcurrentchannel(input: "", guild: "")
                    webSocketClient.data = []
                    webSocketClient.messageIDs = []
                    webSocketClient.usernames = []
                    webSocketClient.disconnect()
                }
            List {
                NavigationLink(destination: ContentView(webSocketClient: webSocketClient)) {
                    Label("Welcome", systemImage: "star")
                }
                
                Spacer()
                
                List {
                    ForEach(guilds.filter { guild in
                        searchTerm.isEmpty || guild.name.lowercased().contains(searchTerm.lowercased())
                    }, id: \.id) { guild in
                        NavigationLink {
                            // ChannelView(webSocketClient: webSocketClient, token: token)
                            ServerView(webSocketClient: webSocketClient, token: token, username: username, serverId: guild.id)
                        } label: {
                            HStack {
                                if guild.icon != nil {
                                    AsyncImage(url: URL(string: guild.icon!)) { image in
                                        image.resizable()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        ProgressView()
                                    }
                                }
                                // AsyncImage(url: URL(string: guild.icon!))
                                Text(guild.name)
                                    
                            }
                        }
                        .onAppear() {
                            webSocketClient.getcurrentchannel(input: "", guild: "")
                        }
                        
                        /* Button(action: {
                         // print("Guild ID: \(guild.id)")
                         }) {
                         Text(guild.name)
                         }
                         */
                    }
                }
                
                Spacer()
                
                Divider()
                NavigationLink(destination: ContentView(webSocketClient: webSocketClient)) {
                    Label("Sign Out", systemImage: "arrow.backward")
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Explore")
            .frame(minWidth: 150, idealWidth: 250, maxWidth: 300)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar, label: {
                        Image(systemName: "sidebar.left")
                    })
                }
            }
        
        }
    }
}

// Toggle Sidebar Function
func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
}
