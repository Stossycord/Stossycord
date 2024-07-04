//
//  SettingsView.swift
//  Stossycord
//
//  Created by Stossy11 on 30/5/2024.
//

//
//  SettingsView.swift
//  Stossycord
//
//  Created by Stossy11 on 30/5/2024.
//

import SwiftUI
import KeychainSwift
import Starscream

struct SettingsView: View {
    @ObservedObject var webSocketClient: WebSocketClient
    @AppStorage("ISOpened") var hasbeenopened = true
    let keychain = KeychainSwift()
    @Binding var token: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Settings")) {
                        Toggle("Show All Server Emojis (most will not work unless you have nitro)", isOn: $webSocketClient.hasnitro)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        Toggle("Enable TTS When Message Sent", isOn: $webSocketClient.hastts)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }

                    Section {
                        Button(action: {
                            keychain.set("", forKey: "token")
                            token = ""
                            hasbeenopened = true
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Log Out")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    }
                }
                Text("App Version 0.0.6")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            }
            .padding()
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
    }
}
