//
//  SettingsView.swift
//  Stossycord
//
//  Created by Stossy11 on 30/5/2024.
//

import SwiftUI
import KeychainSwift

struct SettingsView: View {
    @ObservedObject var webSocketClient: WebSocketClient
    @AppStorage("ISOpened") var hasbeenopened = true
    let keychain = KeychainSwift()
    @Binding var token: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            Toggle("Show All Server Emojis (most will not work unless you have nitro)", isOn: $webSocketClient.hasnitro)
            Toggle("Enable TTS When Message Sent", isOn: $webSocketClient.hastts)
            Button("Log Out") {
                keychain.set("", forKey: "token")
                token = ""
                hasbeenopened = true
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
