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
    @EnvironmentObject var user: CurrentUserService
    @StateObject var guildManager = CurrentUserService.shared.guildManager
    @Environment(\.api) var discordAPI
    @State var updateUI: Bool = false
    @StateObject var webSocketService: WebSocketService
    @AppStorage("hideRestrictedChannels") private var hideRestrictedChannels: Bool = false
    @State var currentChannel: Channel? = nil
    let initialNavigationRequest: ChatNavigationRequest?
    @State private var navigationChannel: Channel? = nil
    @State private var handledNavigationRequestIds: Set<UUID> = []
    
    @State var hasSelectedOnce: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibilityBackport = .all
    
    init(
        guild: Guild,
        webSocketService: WebSocketService,
        initialNavigationRequest: ChatNavigationRequest? = nil
    ) {
        _guild = State(initialValue: guild)
        _webSocketService = StateObject(wrappedValue: webSocketService)
        self.initialNavigationRequest = initialNavigationRequest
    }
    
    
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                
                if #available(iOS 16.0, *) {
                    NavigationSplitView(columnVisibility: NavigationSplitViewVisibilityBackport.convertToNavigationViewVisibility($columnVisibility)) {
                        channelsList
                            .navigationTitle(guild.name)
                    } detail: {
                        if let channel = currentChannel {
                            channelDestination(for: channel, isThread: false)
                                .id(channel.id)
                        } else {
                            Text("Select a channel")
                        }
                    }
                } else {
                    
                    
                    NavigationSplitViewBackport(columnVisibility: $columnVisibility) {
                        channelsList
                            .navigationTitle(guild.name)
                    } detail: {
                        if let channel = currentChannel {
                            channelDestination(for: channel, isThread: false)
                                .id(channel.id)
                        } else {
                            Text("Select a channel")
                        }
                    }
                    .animation(.easeInOut)
                    .onChange(of: columnVisibility) { newValue in
                        print("Sidebar visibility changed to \(newValue)")
                        
                        switch newValue {
                        case .all:
                            print("Sidebar is visible")
                        case .detailOnly:
                            print("Sidebar is hidden")
                        case .doubleColumn:
                            print("Double column mode")
                        default:
                            break
                        }
                    }
                }
            } else {
                
                channelsList
                    .id(updateUI)
                    .navigationTitle(guild.name)
#if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
#endif
#if os(macOS)
                    .navigationSubtitle("Channels")
#endif
            }
        }
        .task {
            if !user.token.isEmpty {
                await channels()
            }
        }
        .onAppear {
            print("cool")
            
            if !user.token.isEmpty {
                webSocketService.requestGuildMembers(guildID: guild.id)
                
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    Task.detached(priority: .userInitiated) {
                        let roles = try? await discordAPI.makeRequest(.roles, args: [guild.id])
                        
                        await MainActor.run {
                            user.guildManager.roles[guild.id] = roles ?? []
                        }
                    }
                }
            }
            
            handleChatNavigationRequest(initialNavigationRequest)
            handleChatNavigationRequest(user.pendingChatNavigationRequest)
        }
        .onChange(of: user.pendingChatNavigationRequest) { request in
            handleChatNavigationRequest(request)
        }
        .onReceive(user.$channelStore) { _ in
            handleChatNavigationRequest(initialNavigationRequest)
            handleChatNavigationRequest(user.pendingChatNavigationRequest)
        }
    }
    
    private var channelsList: some View {
        List {
            if (guildManager.channels[guild.id] ?? []).isEmpty {
                Text("No channels available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(guildManager.channels[array: guild.id], id: \.id) { category in
                    categorySection(for: category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(channelNavigationLink)
    }
    
    @ViewBuilder
    private func categorySection(for category: Category) -> some View {
        let context = categoryContext(from: category)
        let channels = visibleChannels(in: category)
        
        if !channels.isEmpty {
            Section {
                ForEach(channels, id: \.id) { channel in
                    channelRow(channel: channel, category: context, isThread: false)
                    
                    let threads = visibleThreads(for: channel, in: context)
                    if !threads.isEmpty {
                        ForEach(threads, id: \.id) { thread in
                            channelRow(channel: thread, category: context, isThread: true)
                        }
                    }
                }
            } header: {
                sectionHeader(for: category)
            }
        }
    }
    
    
    private func categoryContext(from category: Category) -> Category? {
        category.id == "0" ? nil : category
    }
    
    private func visibleChannels(in category: Category) -> [Channel] {
        let context = categoryContext(from: category)
        return category.channelIds.compactMap { user.channel(withId: $0) }.filter { channel in
            guard hideRestrictedChannels else { return true }
            return PermissionManager.canViewChannel(
                currentUser: user.user ?? User(id: "", username: "", discriminator: "", avatar: ""),
                members: user.guildManager.members[guild.id] ?? [],
                roles: user.guildManager.roles[array: guild.id],
                channel: channel,
                guildId: guild.id,
                categoryOverwrites: context?.permissionOverwrites
            )
        }
    }
    
    private func visibleThreads(for channel: Channel, in category: Category?) -> [Channel] {
        let threads = user.threads(forParent: channel.id)
        if hideRestrictedChannels {
            return threads.filter { thread in
                PermissionManager.canViewChannel(
                    currentUser: user.user ?? User(id: "", username: "", discriminator: "", avatar: ""),
                    members: user.guildManager.members[channel.guildId ?? ""] ?? [],
                    roles: user.guildManager.roles[array: guild.id],
                    channel: thread,
                    guildId: guild.id,
                    categoryOverwrites: category?.permissionOverwrites
                )
            }
        }
        return threads
    }
    
    @ViewBuilder
    private func channelRow(channel: Channel, category: Category?, isThread: Bool) -> some View {
        if channel.isTextLike {
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button {
                    if currentChannel != channel {
                        hasSelectedOnce = true
                        currentChannel = nil
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            columnVisibility = .detailOnly
                            currentChannel = channel
                        }
                    }
                } label: {
                    channelLabel(for: channel, isThread: isThread)
                }
                .disabled(channel.threadMetadata?.archived == true)
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    channelDestination(for: channel, isThread: isThread)
                } label: {
                    channelLabel(for: channel, isThread: isThread)
                }
                .disabled(channel.threadMetadata?.archived == true)
            }
        } else {
            channelLabel(for: channel, isThread: isThread)
                .foregroundStyle(.secondary)
        }
    }
    
    private func channelLabel(for channel: Channel, isThread: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: channel, isThread: isThread))
                .foregroundStyle(iconColor(for: channel, isThread: isThread))
                .frame(width: 18)
                .mentionBadge(count: user.unreadMentionCount(channelId: channel.id))
            
            Text(displayTitle(for: channel, isThread: isThread))
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if channel.threadMetadata?.archived == true {
                Text("Archived")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.leading, isThread ? 24 : 0)
        .contentShape(Rectangle())
    }
    
    private func iconName(for channel: Channel, isThread: Bool) -> String {
        if isThread {
            return "text.bubble"
        }
        
        switch channel.type {
        case 0:
            return "number"
        case 2:
            return "speaker.wave.2"
        case 5:
            return "megaphone"
        case 10, 11, 12:
            return "text.bubble"
        case 13:
            return "waveform"
        case 15:
            return "bubble.left.and.bubble.right"
        case 16:
            return "photo"
        case 14:
            return "list.bullet.rectangle"
        default:
            return "bubble.left"
        }
    }
    
    private func iconColor(for channel: Channel, isThread: Bool) -> Color {
        if isThread {
            return .secondary
        }
        
        switch channel.type {
        case 0, 2, 5, 13, 14, 15, 16:
            return .secondary
        default:
            return .secondary
        }
    }
    
    private func displayTitle(for channel: Channel, isThread: Bool) -> String {
        if channel.isTextLike {
            return channel.displayName
        }
        return channel.displayName
    }
    
    private func formattedName(for channel: Channel, isThread: Bool) -> String {
        channel.displayName
    }
    
    @ViewBuilder
    private func channelDestination(for channel: Channel, isThread: Bool) -> some View {
        if channel.isForumLike {
            ForumChannelView(
                webSocketService: webSocketService,
                forumChannel: channel,
                guild: guild
            )
        } else {
            ChannelView(
                webSocketService: webSocketService,
                currentchannelname: formattedName(for: channel, isThread: isThread),
                currentid: channel.id,
                currentGuild: guild
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
    
    @ViewBuilder
    private var channelNavigationLink: some View {
        NavigationLink(
            destination: channelNavigationDestination,
            isActive: Binding(
                get: { navigationChannel != nil },
                set: { if !$0 { navigationChannel = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }
    
    @ViewBuilder
    private var channelNavigationDestination: some View {
        if let channel = navigationChannel {
            channelDestination(for: channel, isThread: channel.isThread)
        } else {
            EmptyView()
        }
    }
    
    private func handleChatNavigationRequest(_ request: ChatNavigationRequest?) {
        guard let request,
              !handledNavigationRequestIds.contains(request.id),
              request.mention.guildId == guild.id || user.guildId(containing: request.mention.channelId) == guild.id,
              let channel = user.channel(withId: request.mention.channelId),
              channel.isTextLike,
              channel.threadMetadata?.archived != true else { return }
        
        handledNavigationRequestIds.insert(request.id)
        if UIDevice.current.userInterfaceIdiom == .pad {
            currentChannel = channel
            columnVisibility = .detailOnly
        } else {
            navigationChannel = channel
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            user.consumeChatNavigationRequest(request)
        }
    }
    
    @ViewBuilder
    private func sectionHeader(for category: Category) -> some View {
        if let name = category.name, !name.isEmpty {
            Text(name.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            EmptyView()
        }
    }
    
    func channels() async {
        
        let fetchedChannels = guild.channels ?? []
        let fetchedThreads = guild.threads ?? []
        
        print("Fetchced Channels \(fetchedChannels.count)")
        
        let channelSort: (Channel, Channel) -> Bool = { lhs, rhs in
            let lhsIsVoiceLike = lhs.isVoiceLike
            let rhsIsVoiceLike = rhs.isVoiceLike
            
            if lhsIsVoiceLike != rhsIsVoiceLike {
                return !lhsIsVoiceLike
            }
            
            let lhsPosition = lhs.position ?? Int.max
            let rhsPosition = rhs.position ?? Int.max
            
            if lhsPosition == rhsPosition {
                return snowflake(lhs.id) < snowflake(rhs.id)
            }
            
            return lhsPosition < rhsPosition
        }
        
        var categories: [String: Category] = [:]
        fetchedChannels
            .filter { $0.isCategory }
            .forEach { channel in
                categories[channel.id] = Category(
                    id: channel.id,
                    name: channel.name,
                    type: channel.type,
                    position: channel.position,
                    permissionOverwrites: channel.permissionOverwrites,
                    channelIds: []
                )
            }
        
        var orphanedChannels: [String: [Channel]] = [:]
        var rootChannels: [Channel] = []
        
        fetchedChannels
            .filter { !$0.isCategory && !$0.isThread }
            .forEach { channel in
                guard let parentId = channel.parentId else {
                    rootChannels.append(channel)
                    return
                }
                
                if var category = categories[parentId] {
                    category.channelIds.append(channel.id)
                    categories[parentId] = category
                } else {
                    orphanedChannels[parentId, default: []].append(channel)
                }
            }
        
        orphanedChannels.forEach { parentId, channels in
            let sortedChannels = channels.sorted(by: channelSort)
            let resolvedPosition = channels.compactMap { $0.position }.min()
            
            categories[parentId] = Category(
                id: parentId,
                name: nil,
                type: 4,
                position: resolvedPosition,
                permissionOverwrites: nil,
                channelIds: sortedChannels.map(\.id)
            )
        }
        
        let orderedCategories = categories.values.map { category -> Category in
            var mutableCategory = category
            mutableCategory.channelIds.sort { lhs, rhs in
                guard let lhsChannel = fetchedChannels.first(where: { $0.id == lhs }),
                      let rhsChannel = fetchedChannels.first(where: { $0.id == rhs }) else {
                    return snowflake(lhs) < snowflake(rhs)
                }
                
                return channelSort(lhsChannel, rhsChannel)
            }
            return mutableCategory
        }
            .sorted { lhs, rhs in
                let lhsPosition = lhs.position ?? Int.max
                let rhsPosition = rhs.position ?? Int.max
                
                if lhsPosition == rhsPosition {
                    return snowflake(lhs.id) < snowflake(rhs.id)
                }
                
                return lhsPosition < rhsPosition
            }
        
        rootChannels.sort(by: channelSort)
        
        var finalCategories = orderedCategories
        let rootCategory = Category(
            id: "0",
            name: nil,
            type: 4,
            position: -1,
            permissionOverwrites: nil,
            channelIds: rootChannels.map(\.id)
        )
        finalCategories.insert(rootCategory, at: 0)
        
        let finalCategoriesAsync = finalCategories
        await MainActor.run {
            print("Fetched Channels \(finalCategoriesAsync.count)")
            user.setGuildChannels(fetchedChannels, for: guild.id)
            user.setGuildThreads(fetchedThreads, for: guild.id)
            guildManager.objectWillChange.send()
            guildManager.channels[array: guild.id] = finalCategoriesAsync
        }
        
        func snowflake(_ id: String?) -> UInt64 {
            guard let id = id, let value = UInt64(id) else { return 0 }
            return value
        }
    }
}
