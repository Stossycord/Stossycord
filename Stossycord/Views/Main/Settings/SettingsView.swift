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
#if os(iOS)
import CoreLocation
#endif
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
    @ObservedObject private var user = CurrentUserService.shared
    @AppStorage("disableAnimatedAvatars") private var disableAnimatedAvatars: Bool = false
    @AppStorage("disableProfilePictureTap") private var disableProfilePictureTap: Bool = false
    @AppStorage("disableProfilePicturesCache") private var disableProfilePicturesCache: Bool = false
    @AppStorage("disableProfileCache") private var disableProfileCache: Bool = false
    @AppStorage("hideRestrictedChannels") private var hideRestrictedChannels: Bool = false
    @AppStorage("useNativePicker") private var useNativePicker: Bool = true
    @AppStorage("useRedesignedMessages") private var useRedesignedMessages: Bool = true
    @AppStorage("useDiscordFolders") private var useDiscordFolders: Bool = true
    @AppStorage("ignoreChatPermissions") private var ignoreChatPermissions: Bool = false
    @AppStorage(DesignSettingsKeys.allowFakeNitroEmojis) private var allowFakeNitroEmojis: Bool = true
    @AppStorage(DesignSettingsKeys.messageBubbleStyle) private var messageStyleRawValue: String = ""
    @AppStorage(DesignSettingsKeys.showSelfAvatar) private var showSelfAvatar: Bool = true
    @AppStorage(DesignSettingsKeys.hideProfilePictures) private var hideProfilePictures: Bool = false
    @AppStorage(DesignSettingsKeys.customMessageBubbleJSON) private var customBubbleJSON: String = ""
    @AppStorage("allowDestructiveActions") private var allowDestructiveActions: Bool = false
    @AppStorage("keepAlivePingsEnabled") private var keepAlivePingsEnabled: Bool = true
    @AppStorage("keepAlivePingInterval") private var keepAlivePingInterval: Double = 30
    @AppStorage("pingNotificationsEnabled") private var pingNotificationsEnabled: Bool = true
    @AppStorage("foregroundPingBannersEnabled") private var foregroundPingBannersEnabled: Bool = true
    @AppStorage("pingNotificationSoundsEnabled") private var pingNotificationSoundsEnabled: Bool = true
    @AppStorage("pingAllDMsEnabled") private var pingAllDMsEnabled: Bool = false
    #if os(iOS)
    @AppStorage("backgroundLocationSupportEnabled") private var backgroundLocationSupportEnabled: Bool = false
    @ObservedObject private var backgroundLocationService = BackgroundLocationService.shared
    #endif
    @State private var currentUserProfile: UserProfile?
    @State private var profileDisplayName: String = ""
    @State private var profileBio: String = ""
    @State private var profilePronouns: String = ""
    @State private var profileMessage: String?
    @State private var isLoadingProfile: Bool = false
    @State private var isSavingProfile: Bool = false
    @State private var discordStatus: String = "online"
    @State private var customStatusText: String = ""
    @State private var settingsDeveloperMode: Bool = false
    @State private var settingsRenderEmbeds: Bool = true
    @State private var settingsInlineAttachmentMedia: Bool = true
    @State private var settingsGifAutoPlay: Bool = true
    @State private var settingsAnimateEmoji: Bool = true
    @State private var settingsShowCurrentGame: Bool = true
    @State private var isSavingDiscordSettings: Bool = false
    @State private var discordSettingsMessage: String?
    @State private var isLoggingOut: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("My Profile") {
                    SettingsProfilePreview(profile: currentUserProfile, user: user.user)
                }
                
                Section("Profile Editor") {
                    TextField("Name", text: $profileDisplayName)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bio")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        TextEditor(text: $profileBio)
                            .frame(minHeight: 86)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }
                    
                    TextField("Pronouns", text: $profilePronouns)
                    
                    HStack {
                        Button {
                            Task { await saveProfile() }
                        } label: {
                            if isSavingProfile {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Save profile")
                            }
                        }
                        .disabled(user.token.isEmpty || isSavingProfile)
                        
                        if isLoadingProfile {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        
                        Spacer()
                    }
                    
                    if let profileMessage {
                        Text(profileMessage)
                            .font(.caption)
                            .foregroundColor(profileMessage.hasPrefix("Saved") ? .green : .red)
                    }
                }

                Section("Discord Settings") {
                    Picker("Status", selection: $discordStatus) {
                        Text("Online").tag("online")
                        Text("Idle").tag("idle")
                        Text("Do Not Disturb").tag("dnd")
                        Text("Invisible").tag("invisible")
                    }
                    
                    TextField("Custom status", text: $customStatusText)
                    
                    Toggle("Developer Mode", isOn: $settingsDeveloperMode)
                    Toggle("Render embeds", isOn: $settingsRenderEmbeds)
                    Toggle("Inline attachment media", isOn: $settingsInlineAttachmentMedia)
                    Toggle("GIF autoplay", isOn: $settingsGifAutoPlay)
                    Toggle("Animate emoji", isOn: $settingsAnimateEmoji)
                    Toggle("Show current game", isOn: $settingsShowCurrentGame)
                    
                    Button {
                        Task { await saveDiscordSettings() }
                    } label: {
                        if isSavingDiscordSettings {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Save Discord settings")
                        }
                    }
                    .disabled(user.token.isEmpty || isSavingDiscordSettings)
                    
                    if let discordSettingsMessage {
                        Text(discordSettingsMessage)
                            .font(.caption)
                            .foregroundColor(discordSettingsMessage.hasPrefix("Saved") ? .green : .red)
                    }
                }
                

                Section {
                    Toggle("System ping notifications", isOn: $pingNotificationsEnabled)
                    Toggle("In-app ping banners", isOn: $foregroundPingBannersEnabled)
                    Toggle("Notification sounds", isOn: $pingNotificationSoundsEnabled)
                        .disabled(!pingNotificationsEnabled)
                    Toggle("Ping for every DM", isOn: $pingAllDMsEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Ping alerts are created when Discord marks a message as mentioning you. Turn on DM pings to also alert for every direct message.")
                }

#if os(iOS)
                Section {
                    Toggle("Background location support", isOn: Binding(
                        get: { backgroundLocationSupportEnabled },
                        set: { newValue in
                            backgroundLocationSupportEnabled = newValue
                            backgroundLocationService.setEnabled(newValue)
                        }
                    ))
                    
                    HStack {
                        Text("Location permission")
                        Spacer()
                        Text(locationAuthorizationStatusText(backgroundLocationService.authorizationStatus))
                            .foregroundColor(locationAuthorizationStatusColor(backgroundLocationService.authorizationStatus))
                            .font(.subheadline)
                    }
                    
                    if backgroundLocationSupportEnabled && backgroundLocationService.authorizationStatus != .authorizedAlways {
                        Button("Request Always location access") {
                            backgroundLocationService.requestAuthorizationAndStart()
                        }
                    }
                } header: {
                    Text("Background Keep Alive")
                } footer: {
                    Text("Background location is required to keep the app running in the background and does NOT transmit your location ANYWHERE.")
                }
#endif

                Section("Appearance") {
                    Toggle("Hide profile pictures", isOn: $hideProfilePictures)
                        .help("When enabled, user profile pictures won't be shown or loaded.")
                    Toggle("Disable animated avatars", isOn: $disableAnimatedAvatars)
                        .help("When enabled, animated profile pictures will be requested as PNG and shown as a static first frame.")
                    Toggle("Disable profile picture tap", isOn: $disableProfilePictureTap)
                        .help("When enabled, tapping profile pictures won't open user profiles.")
                }

                Section("Design") {
                    Picker("Message style", selection: $messageStyleRawValue) {
                        if useRedesignedMessages {
                            ForEach(MessageBubbleStyle.allCases) { style in
                                Text(style.displayName).tag(style.rawValue)
                            }
                        } else {
                            ForEach(MessageBubbleStyle.allCases) { style in
                                if style == .default {
                                    Text("Discord").tag(style.rawValue)
                                } else if style != .custom {
                                    Text(style.displayName).tag(style.rawValue)
                                }
                            }
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
                    if !user.hasNitro {
                        Toggle("Enable FakeNitro emojis", isOn: $allowFakeNitroEmojis)
                            .help("When disabled, the emoji picker hides animated emojis and emojis from other servers, and messages won't convert them to image links.")
                    }
                    Toggle("Use native picker", isOn: $useNativePicker)
                        .help("When enabled, uses the native iOS picker for selecting photos and files instead of the custom interface.")
                    Toggle("Use redesigned messages", isOn: $useRedesignedMessages)
                        .help("When enabled, messages from the same author within 30 minutes are grouped together and images without text don't show message bubbles.")
                    Toggle("Use Discord server folders", isOn: $useDiscordFolders)
                        .help("When enabled, servers are organized using your Discord folder structure.")
                    Toggle("Ignore Chat Permissions", isOn: $ignoreChatPermissions)
                        .help("When enabled, chat permissions are disabled. Incase you're having issues.")
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
                            Task {
                                await logOut()
                            }
                        } label: {
                            Text(isLoggingOut ? "Logging Out..." : "Log Out")
                        }
                        .disabled(isLoggingOut || user.token.isEmpty)
                    }
                }

                Section("Warning zone") {
                    Toggle("Allow destructive actions", isOn: Binding(
                        get: { allowDestructiveActions },
                        set: { newValue in
                            if newValue {
                                showPopover = true
                            } else {
                                allowDestructiveActions = false
                            }
                        }
                    ))
                    .help("When enabled, allows actions like mass leaving servers.")
                    .foregroundColor(allowDestructiveActions ? .red : .primary)
                    .sheet(isPresented: $showPopover) {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 24) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.yellow)
                                    .padding(.top, 16)
                                    .padding(.bottom, 16)

                                Text("Are you sure?")
                                    .font(.system(size: 38, weight: .bold))

                                Text("This will enable options like mass leaving servers or other features that do not exist on official Discord distributions. Discord could suspend your account for using these features. Proceed with caution.")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: 600, alignment: .leading)
                            }
                            .padding(.horizontal, 34)

                            Spacer()

                            VStack(spacing: 12) {
                                if #available(iOS 19.0, *) {
                                    Button(action: {
                                        allowDestructiveActions = true
                                        showPopover = false
                                    }) {
                                        Text("Enable")
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 40)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .glassEffect(.regular)
                                    
                                    Button(action: {
                                        allowDestructiveActions = false
                                        showPopover = false
                                    }) {
                                        Text("Nevermind")
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 40)
                                    }
                                    .buttonStyle(.bordered)
                                    .glassEffect(.regular)
                                } else {
                                    Button(action: {
                                        allowDestructiveActions = true
                                        showPopover = false
                                    }) {
                                        Text("Enable")
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 56)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    
                                    Button(action: {
                                        allowDestructiveActions = false
                                        showPopover = false
                                    }) {
                                        Text("Nevermind")
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 56)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .padding(.top, 20)
                        .background(Color(UIColor.systemBackground))
                        /*.presentationDetents {
                            if #available(iOS 16.0, *) {
                                [.fraction(0.5), .large]
                            } else {
                                []
                            }
                        } */
                        #if !os(iOS)
                        .frame(maxHeight: .infinity)
                        #endif
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
            .onAppear {
                presenceManager.refreshAuthorizationStatus()
                syncDiscordSettingsFields()
            }
            .task {
                await loadProfile()
            }
            .onReceive(user.$userSettings) { _ in
                syncDiscordSettingsFields()
            }
            .navigationTitle("Settings")
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
                Task { @MainActor in 
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
            Task { @MainActor in 
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
            messageStyleRawValue = useRedesignedMessages ? MessageBubbleStyle.default.rawValue : MessageBubbleStyle.imessage.rawValue
        }
    }

    @MainActor
    func logOut() async {
        guard !isLoggingOut else { return }

        isLoggingOut = true
        defer { isLoggingOut = false }

        do {
            let _: String = try await DiscordAPI.shared.makeRequest(.logout)
        } catch {
            print("Discord logout request failed: \(error.localizedDescription)")
        }

        WebSocketService.shared.disconnect()
        user.clearLocalSession(reason: "user logged out")
    }

    @MainActor
    func loadProfile() async {
        guard !user.token.isEmpty, let userId = user.user?.id else {
            syncProfileFields(from: nil)
            return
        }
        
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        
        do {
            let profile: UserProfile = try await DiscordAPI.shared.makeRequest(.userProfile, args: [userId])
            currentUserProfile = profile
            syncProfileFields(from: profile)
        } catch {
            profileMessage = "Could not load profile: \(error.localizedDescription)"
            syncProfileFields(from: nil)
        }
    }

    @MainActor
    func saveProfile() async {
        guard !user.token.isEmpty else { return }
        
        isSavingProfile = true
        profileMessage = nil
        defer { isSavingProfile = false }
        
        do {
            let currentName = user.user?.global_name ?? ""
            if profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) != currentName {
                let _: String = try await DiscordAPI.shared.makeRequest(.updateCurrentUserInfo, args: [profileDisplayName])
            }
            
            let _: String = try await DiscordAPI.shared.makeRequest(.updateUserProfile, args: [profileBio, profilePronouns])
            
            if let refreshedUser: User = try? await DiscordAPI.shared.makeRequest(.currentUser) {
                user.user = refreshedUser
            }
            
            await loadProfile()
            profileMessage = "Saved profile changes."
        } catch {
            profileMessage = "Could not save profile: \(error.localizedDescription)"
        }
    }

    @MainActor
    func saveDiscordSettings() async {
        guard !user.token.isEmpty else { return }
        
        isSavingDiscordSettings = true
        discordSettingsMessage = nil
        defer { isSavingDiscordSettings = false }
        
        var payload: [String: Any] = [
            "status": discordStatus,
            "developer_mode": settingsDeveloperMode,
            "render_embeds": settingsRenderEmbeds,
            "inline_attachment_media": settingsInlineAttachmentMedia,
            "gif_auto_play": settingsGifAutoPlay,
            "animate_emoji": settingsAnimateEmoji,
            "show_current_game": settingsShowCurrentGame
        ]
        
        let trimmedStatus = customStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        payload["custom_status"] = trimmedStatus.isEmpty ? NSNull() : ["text": trimmedStatus]
        
        do {
            let settings: UserSettings = try await DiscordAPI.shared.makeRequest(.updateUserSettings, args: [payload])
            user.userSettings = settings
            syncDiscordSettingsFields()
            discordSettingsMessage = "Saved Discord settings."
        } catch {
            discordSettingsMessage = "Could not save Discord settings: \(error.localizedDescription)"
        }
    }

    func syncProfileFields(from profile: UserProfile?) {
        let account = profile?.user ?? user.user
        profileDisplayName = account?.global_name ?? ""
        profileBio = profile?.userProfile?.bio ?? account?.bio ?? ""
        profilePronouns = profile?.userProfile?.pronouns ?? account?.pronouns ?? ""
    }

    func syncDiscordSettingsFields() {
        guard let settings = user.userSettings else { return }
        
        discordStatus = settings.status ?? "online"
        customStatusText = settings.customStatus?.text ?? ""
        settingsDeveloperMode = settings.developerMode ?? false
        settingsRenderEmbeds = settings.renderEmbeds ?? true
        settingsInlineAttachmentMedia = settings.inlineAttachmentMedia ?? true
        settingsGifAutoPlay = settings.gifAutoPlay ?? true
        settingsAnimateEmoji = settings.animateEmoji ?? true
        settingsShowCurrentGame = settings.showCurrentGame ?? true
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

    #if os(iOS)
    func locationAuthorizationStatusText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "While using"
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

    func locationAuthorizationStatusColor(_ status: CLAuthorizationStatus) -> Color {
        switch status {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .secondary
        @unknown default:
            return .secondary
        }
    }
    #endif
}

private struct SettingsProfilePreview: View {
    let profile: UserProfile?
    let user: User?
    
    private var displayName: String {
        profile?.displayName ?? user?.global_name ?? user?.username ?? "Your profile"
    }
    
    private var userTag: String {
        if let profile {
            return profile.userTag
        }
        
        guard let user else { return "@username" }
        if user.discriminator == "0" || user.discriminator.isEmpty {
            return "@\(user.username)"
        }
        return "\(user.username)#\(user.discriminator)"
    }
    
    private var bio: String {
        let loadedBio = profile?.userProfile?.bio ?? user?.bio
        let trimmed = loadedBio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "No bio yet." : trimmed
    }
    
    private var pronouns: String? {
        let loadedPronouns = profile?.userProfile?.pronouns ?? user?.pronouns
        let trimmed = loadedPronouns?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private var hasNitro: Bool {
        profile?.hasNitro == true || user?.hasNitro == true
    }
    
    private var avatarUrl: URL? {
        if let avatarUrl = profile?.avatarUrl {
            return URL(string: avatarUrl)
        }
        
        guard let user, let avatar = user.avatar else { return nil }
        let format = avatar.hasPrefix("a_") ? "gif" : "png"
        return URL(string: "https://cdn.discordapp.com/avatars/\(user.id)/\(avatar).\(format)?size=256")
    }
    
    private var bannerUrl: URL? {
        if let bannerUrl = profile?.bannerUrl {
            return URL(string: bannerUrl)
        }
        
        guard let user, let banner = user.banner else { return nil }
        return URL(string: "https://cdn.discordapp.com/banners/\(user.id)/\(banner).png?size=512")
    }
    
    private var accentColor: Color {
        if let hex = profile?.accentColorHex, let color = Color(hex: hex) {
            return color
        }
        
        if let color = user?.accentColor {
            return Color(hex: color)
        }
        
        return Color(hex: "#5865F2") ?? .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let bannerUrl {
                    CachedAsyncImage(url: bannerUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 108)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(accentColor)
                            .frame(height: 108)
                    }
                } else {
                    Rectangle()
                        .fill(accentColor)
                        .frame(height: 108)
                }
                
                SettingsAvatarView(url: avatarUrl, fallback: displayName)
                    .offset(x: 16, y: 34)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    if hasNitro {
                        Label("Nitro", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.purple)
                            .labelStyle(.iconOnly)
                            .help("Discord Nitro")
                    }
                    
                    Spacer()
                }
                
                Text(userTag)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let pronouns {
                    Text(pronouns)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
                
                Text(bio)
                    .font(.body)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.16))
        )
        .padding(.vertical, 4)
    }
}

private struct SettingsAvatarView: View {
    let url: URL?
    let fallback: String
    @AppStorage(DesignSettingsKeys.hideProfilePictures) private var hideProfilePictures: Bool = false
    
    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray4))
                        .overlay(ProgressView())
                }
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Text(String(fallback.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 4)
        )
        .shadow(radius: 3, y: 1)
    }
}

#Preview {
    SettingsView()
        .environmentObject(PresenceManager(webSocketService: WebSocketService.shared))
}
