//
//  StossycordApp.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import SwiftUI

@main
struct StossycordApp: App {
    @StateObject var webSocketService = WebSocketService.shared
    @StateObject var settingsManager = SettingsManager()
    @StateObject var presenceManager = PresenceManager(webSocketService: .shared)
    @State var isPresented: Bool = false
    @State var isfirst: Bool = false
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var user: CurrentUserService
    @State var network = true
    @State var firstTime = true
    @State var currentlyFirstTime = true
    @ObservedObject private var userSession = CurrentUserService.shared
    
    @State var unusuallyLongTime = false
    @State var appInactive = false
    
    private var hasStoredToken: Bool {
        userSession.isAuthenticated
    }
    
    private var shouldShowConnectionCover: Bool {
        hasStoredToken && !isPresented && !webSocketService.isConnected
    }
    
    var body: some Scene {
        WindowGroup {
            NavView(webSocketService: webSocketService)
                .environmentObject(presenceManager)
                .environmentObject(userSession)
                .onAppear {
                    presenceManager.start()
#if os(iOS)
                    BackgroundLocationService.shared.startIfNeeded()
#endif
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
#if os(iOS)
                        BackgroundLocationService.shared.startIfNeeded()
#endif
                        if !isfirst {
                            isfirst = true
                        } else {
                            webSocketService.connect()
                            print("App opened")
                        }
                        appInactive = false
                    case .inactive:
                        print("App going inactive")
                        appInactive = true
                    case .background:
                        print("App closed or in background")
#if os(iOS)
                        BackgroundLocationService.shared.startIfNeeded()
#endif
                        appInactive = true
                    @unknown default:
                        break
                    }
                }
                .sheet(isPresented: $isPresented) {
                    WelcomeView(webSocketService: webSocketService)
                }
                .onAppear {
                    if userSession.isAuthenticated {
                        webSocketService.connect()
                    } else {
                        isPresented = true
                    }
                    
                    Task.detached {
                        ZWJSequenceNameStore.shared.load()
                    }
                }
                .overlay {
                    if !network {
                        VStack {
                            Text("You Are Offline")
                            Spacer()
                        }
                    }
                }
                .overlay {
                    if shouldShowConnectionCover {
                        connectionCover
                    }
                }
                .overlay(alignment: .top) {
                    if let mention = userSession.foregroundMentionNotification {
                        ForegroundMentionNotificationView(mention: mention) {
                            userSession.openMentionChat(mention)
                        } onDismiss: {
                            userSession.dismissForegroundMentionNotification(id: mention.id)
                        }
                        .frame(maxWidth: 460)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                        .task(id: mention.id) {
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            await MainActor.run {
                                userSession.dismissForegroundMentionNotification(id: mention.id)
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.86), value: userSession.foregroundMentionNotification?.id)
                .onChange(of: webSocketService.isNetworkAvailable) { newValue in
                    if newValue {
                        print("Network is Avalible")
                    }
                    if !newValue {
                        print("Network is Unavalible")
                    }
                    
                    network = newValue
                }
                .onChange(of: userSession.isAuthenticated) { authenticated in
                    if authenticated {
                        isPresented = false
                        unusuallyLongTime = false
                        webSocketService.connect()
                    } else {
                        webSocketService.disconnect()
                        isPresented = true
                    }
                }
        }
    }
    
    @ViewBuilder
    private var connectionCover: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                
                VStack(spacing: 6) {
                    Text(network ? "Connecting to Discord" : "Waiting for network")
                        .font(.headline)
                    
                    Text(network ? "\(currentlyFirstTime ? "Loading..." : "Reconnecting...")" : "Messages will sync when you are back online.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if network && !currentlyFirstTime {
                    Button("Retry") {
                        webSocketService.connect()
                    }
                    .buttonStyle(.bordered)
                }
                
                if unusuallyLongTime {
                    Divider()
                    
                    Text("This is taking an unusually long time. Please try logging out and logging back in.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Log Out") {
                        Task { @MainActor in
                            webSocketService.disconnect()
                            userSession.clearLocalSession(reason: "user logged out from connection cover")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onAppear() {
            currentlyFirstTime = firstTime
            firstTime = false
            
            if !appInactive {
                Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { timer in
                    guard !shouldShowConnectionCover else { timer.invalidate(); return }
                    
                    unusuallyLongTime = true
                }
            }
        }
    }
}

private struct ForegroundMentionNotificationView: View {
    let mention: MentionItem
    let onOpen: () -> Void
    let onDismiss: () -> Void
    
    private var title: String {
        if let guildName = mention.guildName {
            return "\(mention.authorUsername) in \(mention.channelName) · \(guildName)"
        }
        
        return "\(mention.authorUsername) mentioned you"
    }
    
    private var bodyText: String {
        let trimmed = mention.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sent a message" : trimmed
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                
                Text(bodyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            Spacer(minLength: 8)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08))
        }
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)
        .onTapGesture {
            onOpen()
        }
    }
}
