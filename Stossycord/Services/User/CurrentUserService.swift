//
//  CurrentUserService.swift
//  Stossycord
//
//  Created by Stossy11 on 14/1/2026.
//

import Foundation
import KeychainSwift
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif


struct MentionItem: Identifiable, Codable, Equatable {
    let id: String
    let messageId: String
    let channelId: String
    let guildId: String?
    let guildName: String?
    let channelName: String
    let authorUsername: String
    let authorId: String
    let content: String
    let timestamp: Date
    var isRead: Bool = false
}

struct ChatNavigationRequest: Identifiable, Equatable {
    let id = UUID()
    let mention: MentionItem
}

struct ChannelMessages: Identifiable, Equatable {
    let id: String
    var messages: [Message]
}

extension Array where Element == ChannelMessages {
    subscript(channelId: String) -> [Message]? {
        get {
            first(where: { $0.id == channelId })?.messages
        }
        set {
            if let index = firstIndex(where: { $0.id == channelId }) {
                self[index].messages = newValue ?? []
            } else {
                append(ChannelMessages(id: channelId, messages: newValue ?? []))
            }
        }
    }
}

struct ChannelStore {
    private var channelsById: [String: Channel] = [:]
    private var channelIdsByGuild: [String: Set<String>] = [:]
    private var threadIdsByParent: [String: [String]] = [:]
    private var dmChannelsById: [String: DMs] = [:]

    var dms: [DMs] {
        sortedDMs(Array(dmChannelsById.values))
    }

    var guildChannels: [Channel] {
        channelsById.values.sorted(by: channelSort)
    }

    var threadsByParent: [String: [Channel]] {
        threadIdsByParent.mapValues { ids in
            ids.compactMap { channelsById[$0] }
        }
    }

    func channel(id: String) -> Channel? {
        channelsById[id]
    }

    func dm(id: String) -> DMs? {
        dmChannelsById[id]
    }

    func channels(forGuild guildId: String) -> [Channel] {
        (channelIdsByGuild[guildId] ?? [])
            .compactMap { channelsById[$0] }
            .sorted(by: channelSort)
    }

    func threads(forParent parentId: String) -> [Channel] {
        (threadIdsByParent[parentId] ?? [])
            .compactMap { channelsById[$0] }
    }

    func guildId(containing channelId: String) -> String? {
        channelIdsByGuild.first { $0.value.contains(channelId) }?.key
    }

    mutating func setGuilds(_ guilds: [Guild]) {
        channelsById.removeAll()
        channelIdsByGuild.removeAll()
        threadIdsByParent.removeAll()

        for guild in guilds {
            upsertGuildChannels(guild.channels ?? [], guildId: guild.id, replacingNonThreads: false)
            upsertGuildThreads(guild.threads ?? [], guildId: guild.id, replacingExisting: false)
        }
    }

    mutating func setGuildChannels(_ channels: [Channel], forGuild guildId: String) {
        upsertGuildChannels(channels, guildId: guildId, replacingNonThreads: true)
    }

    mutating func setGuildThreads(_ threads: [Channel], forGuild guildId: String) {
        upsertGuildThreads(threads, guildId: guildId, replacingExisting: true)
    }

    mutating func upsertThread(_ thread: Channel, parentId: String?) {
        channelsById[thread.id] = thread
        if let guildId = thread.guildId {
            channelIdsByGuild[guildId, default: []].insert(thread.id)
        }

        for key in threadIdsByParent.keys where key != parentId {
            threadIdsByParent[key]?.removeAll { $0 == thread.id }
        }

        guard let parentId else { return }
        var ids = threadIdsByParent[parentId] ?? []
        if !ids.contains(thread.id) {
            ids.append(thread.id)
        }
        threadIdsByParent[parentId] = sortedThreadIds(ids)
    }

    mutating func setThreads(_ threads: [Channel], forParent parentId: String) {
        for thread in threads {
            channelsById[thread.id] = thread
            if let guildId = thread.guildId {
                channelIdsByGuild[guildId, default: []].insert(thread.id)
            }
        }
        threadIdsByParent[parentId] = sortedThreadIds(threads.map(\.id))
    }

    mutating func setThreadsByParent(_ threadsByParent: [String: [Channel]]) {
        threadIdsByParent.removeAll()
        for (parentId, threads) in threadsByParent {
            setThreads(threads, forParent: parentId)
        }
    }

    mutating func removeThread(id: String, parentId: String?) {
        channelsById.removeValue(forKey: id)
        for guildId in channelIdsByGuild.keys {
            channelIdsByGuild[guildId]?.remove(id)
        }

        if let parentId {
            threadIdsByParent[parentId]?.removeAll { $0 == id }
        } else {
            for key in threadIdsByParent.keys {
                threadIdsByParent[key]?.removeAll { $0 == id }
            }
        }
    }

    mutating func setDMs(_ channels: [DMs]) {
        dmChannelsById = Dictionary(
            uniqueKeysWithValues: sortedDMs(channels).map { ($0.id, $0) }
        )
    }

    mutating func upsertDM(_ channel: DMs) {
        guard channel.isDirectMessageChannel else { return }
        dmChannelsById[channel.id] = channel
    }

    mutating func updateDMLastMessage(channelId: String, messageId: String) {
        guard let dm = dmChannelsById[channelId],
              snowflakeValue(messageId) >= snowflakeValue(dm.last_message_id) else { return }
        dmChannelsById[channelId] = dm.updatingLastMessageId(messageId)
    }

    mutating func removeDM(channelId: String) {
        dmChannelsById.removeValue(forKey: channelId)
    }

    private mutating func upsertGuildChannels(_ incoming: [Channel], guildId: String, replacingNonThreads: Bool) {
        if replacingNonThreads {
            let retainedThreadIds = (channelIdsByGuild[guildId] ?? []).filter {
                channelsById[$0]?.isThread == true
            }

            for id in channelIdsByGuild[guildId] ?? [] where channelsById[id]?.isThread != true {
                channelsById.removeValue(forKey: id)
            }

            channelIdsByGuild[guildId] = Set(retainedThreadIds)
        }

        for channel in incoming {
            channelsById[channel.id] = channel
            channelIdsByGuild[guildId, default: []].insert(channel.id)
        }
    }

    private mutating func upsertGuildThreads(_ incoming: [Channel], guildId: String, replacingExisting: Bool) {
        if replacingExisting {
            let existingThreadIds = (channelIdsByGuild[guildId] ?? []).filter {
                channelsById[$0]?.isThread == true
            }

            for id in existingThreadIds {
                channelsById.removeValue(forKey: id)
                channelIdsByGuild[guildId]?.remove(id)
            }

            threadIdsByParent = threadIdsByParent.filter { _, ids in
                !ids.allSatisfy { existingThreadIds.contains($0) }
            }
        }

        for thread in incoming {
            channelsById[thread.id] = thread
            channelIdsByGuild[guildId, default: []].insert(thread.id)

            if let parentId = thread.parentId {
                var ids = threadIdsByParent[parentId] ?? []
                if !ids.contains(thread.id) {
                    ids.append(thread.id)
                }
                threadIdsByParent[parentId] = sortedThreadIds(ids)
            }
        }
    }

    private func sortedThreadIds(_ ids: [String]) -> [String] {
        Array(Set(ids)).sorted { lhs, rhs in
            let lhsChannel = channelsById[lhs]
            let rhsChannel = channelsById[rhs]
            return snowflakeValue(lhsChannel?.lastMessageId ?? lhs) > snowflakeValue(rhsChannel?.lastMessageId ?? rhs)
        }
    }

    private func channelSort(_ lhs: Channel, _ rhs: Channel) -> Bool {
        let lhsIsVoiceLike = lhs.isVoiceLike
        let rhsIsVoiceLike = rhs.isVoiceLike

        if lhsIsVoiceLike != rhsIsVoiceLike {
            return !lhsIsVoiceLike
        }

        if lhs.sortPosition == rhs.sortPosition {
            return snowflakeValue(lhs.id) < snowflakeValue(rhs.id)
        }

        return lhs.sortPosition < rhs.sortPosition
    }

    private func sortedDMs(_ channels: [DMs]) -> [DMs] {
        channels
            .filter(\.isDirectMessageChannel)
            .sorted { snowflakeValue($0.last_message_id) > snowflakeValue($1.last_message_id) }
    }

    private func snowflakeValue(_ id: String?) -> UInt64 {
        guard let id, let value = UInt64(id) else { return 0 }
        return value
    }
}

extension EnvironmentValues {
    @Entry var user: CurrentUserService = .shared
}

class CurrentUserService: ObservableObject {
    static var shared = CurrentUserService()
    private let latestMessageIdsKey = "latestMessageIdsByChannel"
    
    let keychain = KeychainSwift()
    @Published private(set) var isAuthenticated: Bool = false

    var token: String {
        get {
            keychain.get("token") ?? ""
        } set {
            if newValue.isEmpty {
                keychain.delete("token")
            } else {
                keychain.set(newValue, forKey: "token")
            }
            updateAuthenticationState(!newValue.isEmpty)
        }
    }
    
    @Published var user: User?
    @Published var data: [ChannelMessages] = []
    @Published private(set) var channelStore = ChannelStore()
    var dms: [DMs] {
        get { channelStore.dms }
        set {
            var store = channelStore
            store.setDMs(newValue)
            channelStore = store
        }
    }
    @Published var presenceByUserId: [String: Presence] = [:]
    @Published var Guilds: [Guild] = [] {
        didSet {
            var store = channelStore
            store.setGuilds(Guilds)
            channelStore = store
            objectWillChange.send()
        }
    }
    
    var readyEvent: ReadyEvent?
    
    @Published var userSettings: UserSettings? = nil
    var threadsByParent: [String: [Channel]] {
        get { channelStore.threadsByParent }
        set {
            var store = channelStore
            store.setThreadsByParent(newValue)
            channelStore = store
        }
    }
    
    @Published var guildManager = CurrentGuildManager.shared
    
    @Published var mentions: [MentionItem] = [] {
        didSet {
            updateApplicationIconBadgeNumber()
        }
    }
    @Published var foregroundMentionNotification: MentionItem?
    @Published var pendingChatNavigationRequest: ChatNavigationRequest?
    private var lastReadMessageIdsByChannel: [String: String] = [:]
    
    var unreadMentionCount: Int { mentions.filter { !$0.isRead }.count }
    var hasNitro: Bool { user?.hasNitro == true }

    func updateApplicationIconBadgeNumber() {
        #if os(iOS)
        let count = unreadMentionCount
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
        #endif
    }

    func unreadMentionCount(channelId: String) -> Int {
        mentions.filter { !$0.isRead && $0.channelId == channelId }.count
    }
    
    func unreadMentionCount(guildId: String) -> Int {
        mentions.filter { !$0.isRead && $0.guildId == guildId }.count
    }
    
    func unreadMentionCount(guildIds: [String]) -> Int {
        let ids = Set(guildIds)
        return mentions.filter { mention in
            guard !mention.isRead, let guildId = mention.guildId else { return false }
            return ids.contains(guildId)
        }.count
    }
    
    
    func addMention(_ item: MentionItem) {
        guard !mentions.contains(where: { $0.messageId == item.messageId }) else { return }
        mentions.insert(item, at: 0)
        if mentions.count > 200 { mentions = Array(mentions.prefix(200)) }
        updateApplicationIconBadgeNumber()
    }
    
    func showForegroundMentionNotification(_ item: MentionItem) {
        foregroundMentionNotification = item
    }
    
    func dismissForegroundMentionNotification(id: String? = nil) {
        guard id == nil || foregroundMentionNotification?.id == id else { return }
        foregroundMentionNotification = nil
    }

    func openMentionChat(_ item: MentionItem) {
        markMentionRead(id: item.id)
        pendingChatNavigationRequest = ChatNavigationRequest(mention: item)
        dismissForegroundMentionNotification(id: item.id)
    }

    func consumeChatNavigationRequest(_ request: ChatNavigationRequest) {
        guard pendingChatNavigationRequest?.id == request.id else { return }
        pendingChatNavigationRequest = nil
    }
    
    func markMentionRead(id: String, sendAck: Bool = true) {
        guard let idx = mentions.firstIndex(where: { $0.id == id }),
              !mentions[idx].isRead else { return }
        let mention = mentions[idx]
        mentions[idx].isRead = true
        updateApplicationIconBadgeNumber()
        
        if sendAck {
            acknowledgeMessage(
                channelId: mention.channelId,
                messageId: mention.messageId
            )
        }
    }
    
    func markAllMentionsRead() {
        let unread = mentions.filter { !$0.isRead }
        for idx in mentions.indices { mentions[idx].isRead = true }
        updateApplicationIconBadgeNumber()
        let newestByChannel = unread.reduce(into: [String: String]()) { result, mention in
            let current = result[mention.channelId]
            if snowflakeValue(mention.messageId) >= snowflakeValue(current) {
                result[mention.channelId] = mention.messageId
            }
        }
        for (channelId, messageId) in newestByChannel {
            acknowledgeMessage(channelId: channelId, messageId: messageId)
        }
    }
    
    func updateReadStates(_ readStateMap: [String: String]) {
        for (channelId, messageId) in readStateMap {
            recordReadState(channelId: channelId, messageId: messageId)
        }
    }
    
    func setDMs(_ channels: [DMs]) {
        var store = channelStore
        store.setDMs(channels)
        channelStore = store
    }
    
    func upsertDM(_ channel: DMs) {
        var store = channelStore
        store.upsertDM(channel)
        channelStore = store
    }
    
    func markDMMessageReceived(channelId: String, messageId: String) {
        var store = channelStore
        store.updateDMLastMessage(channelId: channelId, messageId: messageId)
        channelStore = store
    }
    
    func removeDM(channelId: String) {
        var store = channelStore
        store.removeDM(channelId: channelId)
        channelStore = store
    }

    func setGuildChannels(_ channels: [Channel], for guildId: String) {
        var store = channelStore
        store.setGuildChannels(channels, forGuild: guildId)
        channelStore = store
    }

    func setGuildThreads(_ threads: [Channel], for guildId: String) {
        var store = channelStore
        store.setGuildThreads(threads, forGuild: guildId)
        channelStore = store
    }

    func upsertThread(_ channel: Channel, parentId: String?) {
        var store = channelStore
        store.upsertThread(channel, parentId: parentId)
        channelStore = store
    }

    func setThreads(_ threads: [Channel], forParent parentId: String) {
        var store = channelStore
        store.setThreads(threads, forParent: parentId)
        channelStore = store
    }

    func removeThread(id: String, parentId: String?) {
        var store = channelStore
        store.removeThread(id: id, parentId: parentId)
        channelStore = store
    }

    func channel(withId channelId: String) -> Channel? {
        channelStore.channel(id: channelId)
    }

    func dmChannel(withId channelId: String) -> DMs? {
        channelStore.dm(id: channelId)
    }

    func hasDMChannel(withId channelId: String) -> Bool {
        channelStore.dm(id: channelId) != nil
    }

    func channels(forGuild guildId: String) -> [Channel] {
        channelStore.channels(forGuild: guildId)
    }

    func threads(forParent parentId: String) -> [Channel] {
        channelStore.threads(forParent: parentId)
    }

    func guildId(containing channelId: String) -> String? {
        channelStore.guildId(containing: channelId)
    }
    
    func recordReadState(channelId: String, messageId: String) {
        let current = lastReadMessageIdsByChannel[channelId]
        guard snowflakeValue(messageId) >= snowflakeValue(current) else { return }
        
        lastReadMessageIdsByChannel[channelId] = messageId
        markMentionsRead(channelId: channelId, through: messageId)
    }
    
    func markMentionsRead(channelId: String, through messageId: String) {
        var didChange = false
        
        for idx in mentions.indices {
            guard mentions[idx].channelId == channelId,
                  !mentions[idx].isRead,
                  snowflakeValue(mentions[idx].messageId) <= snowflakeValue(messageId) else { continue }
            
            mentions[idx].isRead = true
            didChange = true
        }
        
        if didChange {
            updateApplicationIconBadgeNumber()
            objectWillChange.send()
        }
    }

    func acknowledgeMessage(channelId: String, messageId: String, ackToken: String? = nil) {
        recordReadState(channelId: channelId, messageId: messageId)
        
        Task {
            do {
                _ = try await DiscordAPI.shared.makeRequest(
                    .ackMessage(channelId: channelId, messageId: messageId, ackToken: ackToken)
                )
            } catch {
                print("HTTP message ack failed, falling back to gateway ack: \(error)")
                WebSocketService.shared.sendMessageAck(channelId: channelId, messageId: messageId)
            }
        }
    }

    @MainActor
    func loadMentionsFromDiscord(readStateMap: [String: String] = [:]) async {
        guard let messages = try? await DiscordAPI.shared.makeRequest(.fetchMentions, args: [100, true, true]) else { return }
        let readStates = lastReadMessageIdsByChannel.merging(readStateMap) { current, incoming in
            snowflakeValue(incoming) > snowflakeValue(current) ? incoming : current
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let items: [MentionItem] = messages.compactMap { msg -> MentionItem? in
            let timestamp: Date? = {
                if let date = formatter.date(from: msg.timestamp) { return date }
                let plain = ISO8601DateFormatter()
                plain.formatOptions = [.withInternetDateTime]
                return plain.date(from: msg.timestamp)
            }()
            guard let timestamp else { return nil }
            
            let isRead = readStates[msg.channelId].map {
                snowflakeValue($0) >= snowflakeValue(msg.id)
            } ?? false
            
            let channel = resolveChannelName(channelId: msg.channelId)
            
            return MentionItem(
                id: msg.id,
                messageId: msg.id,
                channelId: msg.channelId,
                guildId: msg.guildId,
                guildName: channel?.1,
                channelName: channel?.0 ?? msg.channelId,
                authorUsername: msg.author.global_name ?? msg.author.username,
                authorId: msg.author.id,
                content: DiscordMentionFormatter.format(
                    content: msg.content,
                    guildId: msg.guildId,
                    authorUserId: msg.author.id,
                    authorDisplayName: msg.author.global_name ?? msg.author.username,
                    mentions: msg.mentions,
                    userSession: self,
                    style: .plain,
                    linkChannels: false
                ),
                timestamp: timestamp,
                isRead: isRead
            )
        }.reversed()
        
        updateReadStates(readStateMap)
        for item in items { addMention(item) }
    }
    
    func resolveChannelById(_ channelId: String) -> String? {
        if let dm = dmChannel(withId: channelId) {
            let names = dm.recipients?
                .map { $0.global_name ?? $0.username }
                .joined(separator: ", ")
            return names ?? "Direct Message"
        }
        
        if let channel = channel(withId: channelId) {
            return channel.displayName
        }
        
        return nil
    }
    
    func resolveChannelName(channelId: String) -> (String, String?)? {
        if hasDMChannel(withId: channelId) {
            return ("Direct Messages", nil)
        }
        
        if let channel = channel(withId: channelId) {
            let guildId = channel.guildId ?? guildId(containing: channelId)
            let guildName = guildId.flatMap { id in Guilds.first(where: { $0.id == id })?.name }
            return (channel.displayName, guildName)
        }
        
        return nil
    }
    
    private init() {
        isAuthenticated = !token.isEmpty

        if token.isEmpty {
            return
        }
    }

    @MainActor
    func clearLocalSession(reason: String? = nil) {
        if let reason {
            print("Clearing local session: \(reason)")
        }

        keychain.delete("token")
        isAuthenticated = false
        user = nil
        data = []
        channelStore = ChannelStore()
        presenceByUserId = [:]
        Guilds = []
        readyEvent = nil
        userSettings = nil
        guildManager = CurrentGuildManager.shared
        mentions = []
        foregroundMentionNotification = nil
        pendingChatNavigationRequest = nil
        lastReadMessageIdsByChannel = [:]
        AuthService.shared.state = .idle
        updateApplicationIconBadgeNumber()
    }

    private func updateAuthenticationState(_ authenticated: Bool) {
        if Thread.isMainThread {
            isAuthenticated = authenticated
        } else {
            DispatchQueue.main.async {
                self.isAuthenticated = authenticated
            }
        }
    }
    
    
    func updateMessage(id: String, update: (inout Message) -> Void) {
        guard
            let channelIndex = data.firstIndex(where: {
                $0.messages.contains(where: { $0.messageId == id })
            }),
            let msgIndex = data[channelIndex].messages.firstIndex(where: {
                $0.messageId == id
            })
        else { return }
        
        var updatedData = data
        update(&updatedData[channelIndex].messages[msgIndex])
        self.objectWillChange.send()
        data = updatedData
    }
    
    func latestMessageId(for channelId: String) -> String? {
        let stored = UserDefaults.standard.dictionary(forKey: latestMessageIdsKey) as? [String: String]
        return stored?[channelId]
    }
    
    func rememberLatestMessageId(_ messageId: String, for channelId: String) {
        var stored = UserDefaults.standard.dictionary(forKey: latestMessageIdsKey) as? [String: String] ?? [:]
        let current = stored[channelId]
        if snowflakeValue(messageId) >= snowflakeValue(current) {
            stored[channelId] = messageId
            UserDefaults.standard.set(stored, forKey: latestMessageIdsKey)
        }
    }
    
    func rememberLatestMessage(in channelId: String, from messages: [Message]) {
        guard let latest = messages.max(by: { snowflakeValue($0.messageId) < snowflakeValue($1.messageId) }) else { return }
        rememberLatestMessageId(latest.messageId, for: channelId)
    }
    
    func mergeMessages(_ incoming: [Message], into channelId: String) {
        var merged = data[channelId] ?? []
        
        for message in incoming {
            if let index = merged.firstIndex(where: { $0.messageId == message.messageId }) {
                merged[index] = message
            } else {
                merged.append(message)
            }
        }
        
        merged.sort { snowflakeValue($0.messageId) < snowflakeValue($1.messageId) }
        data[channelId] = merged
        rememberLatestMessage(in: channelId, from: merged)
    }
    
    private func snowflakeValue(_ id: String?) -> UInt64 {
        guard let id, let value = UInt64(id) else { return 0 }
        return value
    }
    
    func dateFromSnowflake(_ snowflakeString: String) -> Date? {
        let snowflake = snowflakeValue(snowflakeString)
        let date = (snowflake >> 22) + 1420070400000
        
        return Date(timeIntervalSince1970: TimeInterval(date) / 1000)
    }
    
    func dateFromSnowflakeOp(_ snowflakeString: String) -> Date {
        return dateFromSnowflake(snowflakeString) ?? Date()
    }
    
    func isDividerNeeded(for message: Message, from: Message) -> Bool {
        guard let messageDate = dateFromSnowflake(message.messageId),
                let fromDate = dateFromSnowflake(from.messageId) else { return false }
        
        
        let calendar = Calendar.current
        let startOfDate1 = calendar.startOfDay(for: messageDate)
        let startOfDate2 = calendar.startOfDay(for: fromDate)
        
        return startOfDate1 > startOfDate2
    }
    
}

class CurrentGuildManager: ObservableObject {
    static var shared = CurrentGuildManager()
    
    @Published var channels: [String: [Category]] = [:]
    @Published var roles: [String: [AdvancedGuild.Role]] = [:]
    @Published var members: [String: Set<GuildMember>] = [:]
    @Published var emojis: [String: Set<Emoji>] = [:]
    @Published var typingIndicators: [String: [Typing]] = [:] {
        didSet {
            objectWillChange.send()
        }
    }
    @Published var currentChannel: String = ""
    
    func visibleRoles(_ guild: String) -> [String: Set<GuildMember>] {
        if let members = self.members[guild], let roles = self.roles[guild] {
            
            var returnRoles: [String: Set<GuildMember>] = [:]
            
            for role in roles {
                guard role.hoist else { continue }
                
                returnRoles[role.id] = []
            }
            
            
            for member in members {
                let roles = roles.compactMap { role in
                    member.roles.contains(role.id) ? role : nil
                }
                
                guard let role = roles.first(where: { $0.hoist }) else { continue }
                
                returnRoles[role.id]?.insert(member)
            }
            
            
            return returnRoles
        }
        
        return [:]
    }
}
