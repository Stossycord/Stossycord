//
//  SettingsView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI
import KeychainSwift
import LocalAuthentication
import MusicKit
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
    @EnvironmentObject private var presenceManager: PresenceManager
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    @AppStorage("disableProfilePicturesCache") private var disableProfilePicturesCache: Bool = false
    @AppStorage("disableProfileCache") private var disableProfileCache: Bool = false
    @AppStorage("hideRestrictedChannels") private var hideRestrictedChannels: Bool = false
    @AppStorage("useNativePicker") private var useNativePicker: Bool = false
    @AppStorage("useRedesignedMessages") private var useRedesignedMessages: Bool = false
    @AppStorage("useDiscordFolders") private var useDiscordFolders: Bool = false
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = MessageBubbleStyle.default.rawValue
    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true
    @AppStorage(DesignSettingsKeys.customMessageBubbleJSON) private var customBubbleJSON: String = ""
    
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
                
                Section("Appearance") {
                    Toggle("Disable animated avatars", isOn: $disableAnimatedAvatars)
                        .help("When enabled, animated profile pictures will be requested as PNG and shown as a static first frame.")
                    Toggle("Disable profile picture tap", isOn: $disableProfilePictureTap)
                        .help("When enabled, tapping profile pictures won't open user profiles.")
                }

                Section("Design") {
                    Picker("Message style", selection: $messageStyleRawValue) {
                        ForEach(MessageBubbleStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
#if os(iOS)
                    .pickerStyle(.segmented)
#endif

                    Toggle("Show my profile picture", isOn: $showSelfAvatar)
                        .help("When disabled, your messages align closer to the edge without your avatar.")
                    
                    let selectedStyle = MessageBubbleStyle(rawValue: messageStyleRawValue) ?? .default
                    if selectedStyle == .custom {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom bubble JSON")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            TextEditor(text: $customBubbleJSON)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 160)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
#if os(iOS)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
#endif
                            if !MessageBubbleVisualConfiguration.isCustomJSONValid(customBubbleJSON) {
                                Text("Invalid JSON detected – falling back to defaults.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            HStack(spacing: 12) {
                                Button("Load sample") {
                                    customBubbleJSON = MessageBubbleVisualConfiguration.sampleJSON
                                }
                                Button("Clear") {
                                    customBubbleJSON = ""
                                }
                                .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding(.top, 4)
                    }
                }
                
                Section("Cache") {
                    Toggle("Disable profile pictures cache", isOn: $disableProfilePicturesCache)
                        .help("When enabled, profile pictures won't be cached and will be downloaded every time.")
                    Toggle("Disable profile cache", isOn: $disableProfileCache)
                        .help("When enabled, user profiles and bios won't be cached and will be fetched every time.")
                    
                    HStack {
                        Button("Clear cache") {
                            CacheService.shared.clearAllCaches()
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Text(CacheService.shared.getCacheSizeString())
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Beta") {
                    Toggle("Hide channels you can't see", isOn: $hideRestrictedChannels)
                        .help("When enabled, channels without VIEW_CHANNEL permission will be hidden from the channel list.")
                    Toggle("Use native picker", isOn: $useNativePicker)
                        .help("When enabled, uses the native iOS picker for selecting photos and files instead of the custom interface.")
                    Toggle("Use redesigned messages", isOn: $useRedesignedMessages)
                        .help("When enabled, messages from the same author within 30 minutes are grouped together and images without text don't show message bubbles.")
                    Toggle("Use Discord server folders", isOn: $useDiscordFolders)
                        .help("When enabled, servers are organized using your Discord folder structure.")
                }

                Section("Presence") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Apple Music access")
                            Spacer()
                            Text(authorizationStatusText(presenceManager.authorizationStatus))
                                .foregroundColor(authorizationStatusColor(presenceManager.authorizationStatus))
                                .font(.subheadline)
                        }

                        if presenceManager.authorizationStatus != .authorized {
                            Button {
                                presenceManager.requestAuthorization()
                            } label: {
                                if presenceManager.isRequestingAuthorization {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Text("Request Apple Music access")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(presenceManager.isRequestingAuthorization)
                        } else {
                            Text("Apple Music access is enabled.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        if presenceManager.authorizationStatus == .authorized {
                            Toggle("Share Apple Music status", isOn: $presenceManager.musicPresenceEnabled)
                        } else {
                            Text(authorizationHelpText(for: presenceManager.authorizationStatus))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        if !presenceManager.musicPresenceEnabled {
                            Divider()

                            Text("Custom presence")
                                .font(.headline)

                            TextField("Activity name", text: $presenceManager.customPresenceName)
                            TextField("Details", text: $presenceManager.customPresenceDetails)
                            TextField("State", text: $presenceManager.customPresenceState)

                            Text("Leave the activity name empty to clear your custom presence.")
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            if !presenceManager.customPresenceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                !presenceManager.customPresenceDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                !presenceManager.customPresenceState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(role: .destructive) {
                                    presenceManager.customPresenceName = ""
                                    presenceManager.customPresenceDetails = ""
                                    presenceManager.customPresenceState = ""
                                } label: {
                                    Text("Clear custom presence")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("User info") {
                    Text("Locale: \(WebSocketService.shared.userSettings?.locale ?? "N/A")")
                    Text("Discord Theme: \(WebSocketService.shared.userSettings?.theme ?? "N/A")")
                    Text("Developer Mode: \(WebSocketService.shared.userSettings?.developerMode == true ? "Enabled" : "Disabled")")
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
            .onAppear {
                presenceManager.refreshAuthorizationStatus()
            }
        }
        .onAppear {
            ensureValidMessageStyle()
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

private extension SettingsView {
    func ensureValidMessageStyle() {
        if MessageBubbleStyle(rawValue: messageStyleRawValue) == nil {
            messageStyleRawValue = MessageBubbleStyle.default.rawValue
        }
    }
}

private extension SettingsView {
    func authorizationStatusText(_ status: MusicAuthorization.Status) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not requested"
        @unknown default:
            return "Unknown"
        }
    }

    func authorizationStatusColor(_ status: MusicAuthorization.Status) -> Color {
        switch status {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .restricted:
            return .orange
        case .notDetermined:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    func authorizationHelpText(for status: MusicAuthorization.Status) -> String {
        switch status {
        case .authorized:
            return "Apple Music access is enabled."
        case .notDetermined:
            return "Request access to share what you're listening to from Apple Music."
        case .denied:
            return "Access has been denied. You can re-enable Apple Music permissions from System Settings."
        case .restricted:
            return "Apple Music access is restricted on this device."
        @unknown default:
            return "Apple Music access is currently unavailable."
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(PresenceManager(webSocketService: WebSocketService.shared))
}