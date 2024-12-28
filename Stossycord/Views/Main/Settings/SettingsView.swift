//
//  SettingsView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI
import KeychainSwift
import LocalAuthentication
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SettingsView: View {
    @State var isspoiler: Bool = true
    let keychain = KeychainSwift()
    @State var showAlert: Bool = false
    @State var showPopover = false
    @State var guildID = ""

    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            List {
                Section("Token") {
                
                    
                    
                    HStack {
                        Text("Token: ")
                        ZStack {
                            if isspoiler {
                                Spacer()
                                Image(systemName: "lock.rectangle")
                                    .onTapGesture {
                                        if isspoiler {
                                            authenticate()
                                        } else {
                                            isspoiler = true
                                        }
                                    }
                                Spacer()
                            } else {
                                Text(keychain.get("token") ?? "")
                                    .contextMenu {
                                        Button {
                                            #if os(macOS)
                                            if let token = keychain.get("token") {
                                                let pasteboard = NSPasteboard.general
                                                pasteboard.clearContents() // Clear the pasteboard before writing
                                                pasteboard.setString(token, forType: .string)
                                            } else {
                                                print("No token found in the keychain.")
                                            }
                                            #else
                                            UIPasteboard.general.string = keychain.get("token") ?? ""
                                            #endif
                                        } label: {
                                            Text("Copy")
                                        }
                                    }
                                    .onTapGesture {
                                        isspoiler = true
                                        // token = ""
                                    }
                            }
                        }
                    }
                    
                    
                    ZStack {
                        Button {
                            keychain.delete("token")
                            showAlert = true
                        } label: {
                            Text("Log Out")
                        }
                    }
                }
                /*
                if let token = keychain.get("token") {
                    Section("Servers") {
                        HStack {
                            Text("Join Server: ")
                            
                            TextField("Discord Invite Link", text: $guildID)
                                .onSubmit {
                                    if let inviteID = GetInviteId(from: guildID) {
                                        GetServerID(token: token, inviteID: inviteID) { invite in
                                            print(invite)
                                            if let invite {
                                                joinDiscordGuild(token: token, guildId: invite) { response in
                                                    if response == nil {
                                                        print("Server already joined")
                                                    } else {
                                                        print(response)
                                                    }
                                                }
                                            }
                                        }
                                        
                                    }
                                }
                            
                        }
                    }
                }
                 */
            }
            .alert(isPresented: $showAlert) {
                .init(
                    title: Text("Token Reset"),
                    message: Text("Your token has been reset. Please Quit and Relaunch the App."))
            }
        }
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check whether biometric authentication is possible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // It's possible, so go ahead and use it
            let reason = "This is very Sensitive Data. Please Authenticate"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isspoiler = false
                    } else {
                        // Handle authentication errors
                        if let error = authenticationError as? LAError {
                            switch error.code {
                            case .userFallback:
                                // User chose to use fallback authentication (e.g., passcode)
                                self.authenticateWithPasscode()
                            case .biometryNotAvailable, .biometryNotEnrolled:
                                // Biometric authentication is not available or not set up
                                self.authenticateWithPasscode()
                            default:
                                print("Authentication failed: \(error.localizedDescription)")
                                self.isspoiler = true
                            }
                        }
                    }
                }
            }
        } else {
            // Biometric authentication is not available
            authenticateWithPasscode()
        }
    }

    func authenticateWithPasscode() {
        let context = LAContext()
        let reason = "Please enter your passcode to authenticate"

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isspoiler = false
                } else {
                    print("Passcode authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                    self.isspoiler = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
