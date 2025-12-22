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
    @StateObject var webSocketService: WebSocketService
    @AppStorage("hideRestrictedChannels") private var hideRestrictedChannels: Bool = false

    var body: some View {
        channelsList
            .navigationTitle(guild.name)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
            .navigationSubtitle("Channels")
        #endif
            .onAppear {
            if webSocketService.currentguild.id != guild.id {
                webSocketService.currentguild = guild
                webSocketService.channels.removeAll()
                webSocketService.threadsByParent.removeAll()

                if let token = keychain.get("token") {
                    channels(token: token)
                    webSocketService.requestGuildMembers(guildID: guild.id)

                    Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        getGuildRoles(guild: guild) { roles in
                            Task { @MainActor in 
                                webSocketService.currentroles = roles
                            }
                        }
                    }
                }
            }
        }
    }

    private var channelsList: some View {
        List {
            if webSocketService.channels.isEmpty {
                Text("No channels available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(webSocketService.channels, id: \.id) { category in
                    categorySection(for: category)
                }
            }
        }
        .listStyle(.insetGrouped)
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
        return category.channels.filter { channel in
            guard hideRestrictedChannels else { return true }
            return PermissionManager.canViewChannel(
                currentUser: webSocketService.currentUser,
                members: webSocketService.currentMembers,
                roles: webSocketService.currentroles,
                channel: channel,
                guildId: guild.id,
                categoryOverwrites: context?.permissionOverwrites
            )
        }
    }

    private func visibleThreads(for channel: Channel, in category: Category?) -> [Channel] {
        let threads = webSocketService.threadsByParent[channel.id] ?? []
        if hideRestrictedChannels {
            return threads.filter { thread in
                PermissionManager.canViewChannel(
                    currentUser: webSocketService.currentUser,
                    members: webSocketService.currentMembers,
                    roles: webSocketService.currentroles,
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
            NavigationLink {
                ChannelView(
                    webSocketService: webSocketService,
                    currentchannelname: formattedName(for: channel, isThread: isThread),
                    currentid: channel.id,
                    currentGuild: guild
                )
            } label: {
                channelLabel(for: channel, isThread: isThread)
            }
            .disabled(channel.threadMetadata?.archived == true)
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
            return "# " + channel.displayName
        }
        return channel.displayName
    }

    private func formattedName(for channel: Channel, isThread: Bool) -> String {
        channel.displayName
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

    func channels(token: String) {
        getDiscordChannels(serverId: guild.id, token: token) { fetchedChannels in
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
                        channels: []
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
                        category.channels.append(channel)
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
                    channels: sortedChannels
                )
            }

            var orderedCategories = categories.values.map { category -> Category in
                var mutableCategory = category
                mutableCategory.channels.sort(by: channelSort)
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
                channels: rootChannels
            )
            finalCategories.insert(rootCategory, at: 0)

            // Do not attempt to fetch guild-wide threads (bot-only). Keep threadsByParent empty.
            webSocketService.channels = finalCategories
            webSocketService.threadsByParent = [:]
        }
    }

    private func snowflake(_ id: String?) -> UInt64 {
        guard let id = id, let value = UInt64(id) else { return 0 }
        return value
    }

}
