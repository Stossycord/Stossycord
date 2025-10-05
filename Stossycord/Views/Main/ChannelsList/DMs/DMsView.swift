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
    @State private var searchTerm = ""
    
    var body: some View {
        #if os(macOS)
        VStack {
            content()
        }
        #else
        NavigationStack {
            content()
        }
        #endif
    }
    
    @ViewBuilder
    private func content() -> some View {
        VStack(spacing: 0) {
            // Search bar
            searchField
            
            // DMs list
            conversationsList
                .onAppear {
                    loadDirectMessages()
                }
        }
        .navigationTitle("Messages")
        #if !os(macOS)
        .toolbar(.visible, for: .tabBar)
        #endif
    }
    
    // MARK: - Components
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search conversations", text: $searchTerm)
                .font(.body)
            
            if !searchTerm.isEmpty {
                Button(action: { searchTerm = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredDMs, id: \.id) { channel in
                    NavigationLink(destination: destinationForChannel(channel)) {
                        if channel.type == 1 {
                            DirectMessageRow(channel: channel)
                        } else if channel.type == 3 {
                            GroupChatRow(channel: channel)
                        }
                    }
                    .buttonStyle(ConversationRowButtonStyle())
                }
                
                if filteredDMs.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(searchTerm.isEmpty ? "No conversations yet" : "No matching conversations")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchTerm.isEmpty {
                Button("Clear Search") {
                    searchTerm = ""
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    // MARK: - Logic
    
    private var filteredDMs: [DMs] {
        webSocketService.dms.filter { channel in
            guard searchTerm.isEmpty else {
                if channel.type == 1, let recipient = channel.recipients?.first {
                    let name = recipient.global_name ?? recipient.username
                    return name.localizedCaseInsensitiveContains(searchTerm)
                } else if channel.type == 3 {
                    let names = channel.recipients?.compactMap { $0.global_name ?? $0.username } ?? []
                    return names.joined(separator: " ").localizedCaseInsensitiveContains(searchTerm)
                }
                return false
            }
            return true
        }
    }
    
    private func loadDirectMessages() {
        guard let token = keychain.get("token") else { return }
        getDiscordDMs(token: token) { items in
            webSocketService.dms = items
        }
    }
    
    @ViewBuilder
    private func destinationForChannel(_ channel: DMs) -> some View {
        let channelName = getChannelName(for: channel)
        #if os(macOS)
        ChannelView(webSocketService: webSocketService, currentchannelname: channelName, currentid: channel.id)
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            ChannelView(webSocketService: webSocketService, currentchannelname: channelName, currentid: channel.id)
        } else {
            ChannelView(webSocketService: webSocketService, currentchannelname: channelName, currentid: channel.id)
                .toolbar(.hidden, for: .tabBar)
        }
        #endif
    }
    
    private func getChannelName(for channel: DMs) -> String {
        if channel.type == 1, let recipient = channel.recipients?.first {
            return "@" + (recipient.username)
        } else {
            // For group chats, just return the first recipient's name
            if let recipient = channel.recipients?.first {
                return "@" + recipient.username
            } else {
                return "Chat"
            }
        }
    }
}

// MARK: - Supporting Views

struct DirectMessageRow: View {
    let channel: DMs
    
    var body: some View {
        HStack(spacing: 14) {
            // User avatar
            UserAvatarView(user: channel.recipients?.first)
            
            // Username and status
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text("Tap to view conversation")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var displayName: String {
        guard let recipient = channel.recipients?.first else { return "Unknown" }
        return (recipient.global_name ?? recipient.username)
    }
}

struct GroupChatRow: View {
    let channel: DMs
    
    var body: some View {
        HStack(spacing: 14) {
            GroupAvatarView(users: channel.recipients ?? [])
            
            VStack(alignment: .leading, spacing: 2) {
                Text(groupName)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text("\(channel.recipients?.count ?? 0) members")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var groupName: String {
        let recipientNames = channel.recipients?.prefix(3).map { $0.global_name ?? $0.username } ?? []
        let namesString = recipientNames.joined(separator: ", ")
        if let count = channel.recipients?.count, count > 3 {
            return "Group: \(namesString) +\(count - 3)"
        } else {
            return "Group: \(namesString)"
        }
    }
}

struct UserAvatarView: View {
    let user: User?
    
    var body: some View {
        Group {
            if let user = user, let avatar = user.avatar {
                AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(user.id)/\(avatar).png")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                    case .failure:
                        defaultAvatar
                    case .empty:
                        ProgressView()
                    @unknown default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var defaultAvatar: some View {
        ZStack {
            Circle().fill(Color.indigo.opacity(0.7))
            Text(user?.username.prefix(1).uppercased() ?? "?")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct GroupAvatarView: View {
    let users: [User]
    
    var body: some View {
        ZStack {
            ForEach(0..<min(3, users.count), id: \.self) { index in
                Circle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 30, height: 30)
                    .overlay(
                        UserInitialView(user: users[index])
                    )
                    .offset(getOffset(for: index, total: min(3, users.count)))
            }
        }
        .frame(width: 44, height: 44)
    }
    
    private func getOffset(for index: Int, total: Int) -> CGSize {
        switch (total, index) {
        case (1, 0):
            return CGSize(width: 0, height: 0)
        case (2, 0):
            return CGSize(width: -7, height: 0)
        case (2, 1):
            return CGSize(width: 7, height: 0)
        case (3, 0):
            return CGSize(width: -6, height: 6)
        case (3, 1):
            return CGSize(width: 6, height: 6)
        case (3, 2):
            return CGSize(width: 0, height: -6)
        default:
            return CGSize(width: 0, height: 0)
        }
    }
}

struct UserInitialView: View {
    let user: User
    
    var body: some View {
        ZStack {
            Circle().fill(getColor(for: user.id))
            
            Text(user.username.prefix(1).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func getColor(for id: String) -> Color {
        let colors: [Color] = [.blue, .indigo, .purple, .pink, .orange, .teal, .green]
        let hash = id.hash & 0x7FFFFFFF
        return colors[hash % colors.count]
    }
}

struct ConversationRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension UIApplication {
    var key: UIWindow? {
        self.connectedScenes
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?
            .windows
            .filter({$0.isKeyWindow})
            .first
    }
}


extension UIView {
    func allSubviews() -> [UIView] {
        var subs = self.subviews
        for subview in self.subviews {
            let rec = subview.allSubviews()
            subs.append(contentsOf: rec)
        }
        return subs
    }
}
    

class TabBarModifier: ObservableObject {
    
    
    @Published var tabBarSize: CGFloat
    
    @Published var shown: Bool = false
    
    private init() {
        var tabBar: CGFloat = 0
        
        UIApplication.shared.key?.allSubviews().forEach({ subView in
            if let view = subView as? UITabBar {
                tabBar = view.frame.size.height
            }
        })
        
        self.tabBarSize = tabBar
    }
    
    static var shared: TabBarModifier = .init()
    
    func showTabBar() {
        UIApplication.shared.key?.allSubviews().forEach({ subView in
            if let view = subView as? UITabBar {
                print(view.isHidden)
                view.isHidden = false
            }
        })
    }
    
    func hideTabBar() {
        UIApplication.shared.key?.allSubviews().forEach({ subView in
            if let view = subView as? UITabBar {
                view.isHidden = true
            }
        })
    }
}

struct ShowTabBar: ViewModifier {
    func body(content: Content) -> some View {
        return content.padding(.zero).onAppear {
            TabBarModifier.shared.showTabBar()
        }
    }
}
struct HiddenTabBar: ViewModifier {
    func body(content: Content) -> some View {
        return content.padding(.zero).onAppear {
            TabBarModifier.shared.hideTabBar()
        }
    }
}

extension View {
    
    func showTabBar() -> some View {
        return self.modifier(ShowTabBar())
    }

    func hiddenTabBar() -> some View {
        return self.modifier(HiddenTabBar())
    }
}
