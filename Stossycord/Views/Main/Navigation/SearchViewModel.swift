import Foundation
import Combine

final class SearchViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case messages = "Messages"
        case links = "Links"
        case files = "Files"
        case pins = "Pins"
        case media = "Media"
        case people = "People"
        
        var id: String { rawValue }
    }
    
    @Published var query: String = ""
    @Published var filter: Filter = .all
    @Published private(set) var results = SearchResults()
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSearch = false
    @Published private(set) var showMinimumQueryHint = false
    @Published private(set) var loadingTabs: Set<UnifiedSearchTab> = []
    
    private let minimumQueryLength = 2
    private let webSocketService: WebSocketService
    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()
    private let isoFormatter = ISO8601DateFormatter()
    private var remoteTabStates: [UnifiedSearchTab: RemoteTabState] = [:]
    private var totalResultsByTab: [UnifiedSearchTab: Int] = [:]
    private var localBaseline = SearchResults()
    private var activeQuery: String?
    
    private struct RemoteTabState {
        var results: [MessageResult]
        var cursor: SearchCursor?
        var totalResults: Int?
    }
    
    init(webSocketService: WebSocketService, searchService: SearchService = SearchService()) {
        self.webSocketService = webSocketService
        self.searchService = searchService
        bind()
        refreshDefaults()
    }
    
    func refreshDefaults() {
        var defaults = SearchResults()
        defaults.messages = localMessagesMatching(query: nil, limit: 6)
        defaults.people = suggestedPeople(limit: 8)
        localBaseline = defaults
        remoteTabStates.removeAll()
        totalResultsByTab.removeAll()
        loadingTabs.removeAll()
        activeQuery = nil
        results = defaults
    }
    
    private func bind() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(320), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.handleQueryChange($0) }
            .store(in: &cancellables)
        
        $filter
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.refreshDefaults()
                }
            }
            .store(in: &cancellables)
        
        webSocketService.$dms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleDataRefresh() }
            .store(in: &cancellables)
        
        webSocketService.$channels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleDataRefresh() }
            .store(in: &cancellables)
        
        webSocketService.$currentMembers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleDataRefresh() }
            .store(in: &cancellables)
        
        webSocketService.$data
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleDataRefresh() }
            .store(in: &cancellables)
    }
    
    private func handleDataRefresh() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            refreshDefaults()
            return
        }
        localBaseline = localResults(for: trimmed)
        if showMinimumQueryHint {
            results = localBaseline
        } else {
            composeResults()
        }
    }
    
    private func handleQueryChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchService.cancelOngoing()
            isLoading = false
            errorMessage = nil
            didSearch = false
            showMinimumQueryHint = false
            filter = .all
            resetRemoteState()
            refreshDefaults()
            return
        }
        
        if trimmed.count < minimumQueryLength {
            searchService.cancelOngoing()
            isLoading = false
            showMinimumQueryHint = true
            didSearch = true
            errorMessage = nil
            filter = .all
            resetRemoteState()
            localBaseline = localResults(for: trimmed)
            results = localBaseline
            return
        }
        
        showMinimumQueryHint = false
        runSearch(with: trimmed)
    }
    
    private func resetRemoteState() {
        remoteTabStates.removeAll()
        totalResultsByTab.removeAll()
        loadingTabs.removeAll()
        activeQuery = nil
    }
    
    private func runSearch(with trimmedQuery: String) {
        searchService.cancelOngoing()
        isLoading = true
        errorMessage = nil
        didSearch = true
        resetRemoteState()
    let local = localResults(for: trimmedQuery)
    localBaseline = local
    results = local
        activeQuery = trimmedQuery
        
        let token = webSocketService.token
        guard !token.isEmpty else {
            isLoading = false
            return
        }
        
        let expectedQuery = trimmedQuery
        searchService.searchMessages(token: token, query: trimmedQuery) { [weak self] outcome in
            guard let self = self else { return }
            guard self.activeQueryMatches(expectedQuery) else { return }
            self.isLoading = false
            switch outcome {
            case .success(let unified):
                self.processRemoteResults(unified, query: trimmedQuery, focusedTab: nil, appending: false)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func activeQueryMatches(_ candidate: String) -> Bool {
        guard let activeQuery = activeQuery else { return false }
        return activeQuery.compare(candidate, options: .caseInsensitive) == .orderedSame
    }
    
    private func processRemoteResults(_ unified: UnifiedSearchResults,
                                      query: String,
                                      focusedTab: UnifiedSearchTab?,
                                      appending: Bool) {
        let tabs: [UnifiedSearchTab]
        if let focusedTab = focusedTab {
            tabs = [focusedTab]
        } else {
            tabs = [.messages, .links, .files, .pins, .media]
        }
        for tab in tabs {
            let messages: [Message]
            switch tab {
            case .messages:
                messages = unified.messages
            case .links:
                messages = unified.links
            case .files:
                messages = unified.files
            case .pins:
                messages = unified.pins
            case .media:
                messages = unified.media
            }
            let cursor = unified.cursor(for: tab)
            let total = unified.totalResults(for: tab)
            updateRemoteState(for: tab,
                              messages: messages,
                              query: query,
                              cursor: cursor,
                              total: total,
                              appending: appending)
        }
        composeResults()
    }
    
    private func updateRemoteState(for tab: UnifiedSearchTab,
                                   messages: [Message],
                                   query: String,
                                   cursor: SearchCursor?,
                                   total: Int?,
                                   appending: Bool) {
        let converted = makeMessageResults(from: messages, query: query, origin: .remote)
        if appending, var existing = remoteTabStates[tab] {
            existing.results = mergeMessages(existing.results, with: converted)
            existing.cursor = cursor
            existing.totalResults = total
            remoteTabStates[tab] = existing
        } else {
            remoteTabStates[tab] = RemoteTabState(results: converted, cursor: cursor, totalResults: total)
        }
        totalResultsByTab[tab] = total
    }
    
    private func composeResults() {
        var composed = localBaseline
        if let remoteMessages = remoteTabStates[.messages]?.results {
            composed.messages = mergeMessages(localBaseline.messages, with: remoteMessages)
        }
        if let remoteLinks = remoteTabStates[.links]?.results {
            composed.links = remoteLinks
        }
        if let remoteFiles = remoteTabStates[.files]?.results {
            composed.files = remoteFiles
        }
        if let remotePins = remoteTabStates[.pins]?.results {
            composed.pins = remotePins
        }
        if let remoteMedia = remoteTabStates[.media]?.results {
            composed.media = remoteMedia
        }
        results = composed
    }
    
    func hasMoreResults(for filter: Filter) -> Bool {
        guard let tab = unifiedTab(for: filter) else { return false }
        return remoteTabStates[tab]?.cursor != nil
    }
    
    func isLoadingMore(for filter: Filter) -> Bool {
        guard let tab = unifiedTab(for: filter) else { return false }
        return loadingTabs.contains(tab)
    }
    
    func totalResults(for filter: Filter) -> Int? {
        guard let tab = unifiedTab(for: filter) else { return nil }
        return totalResultsByTab[tab]
    }
    
    func loadMore(for filter: Filter) {
        guard let tab = unifiedTab(for: filter) else { return }
        guard let cursor = remoteTabStates[tab]?.cursor else { return }
        guard let query = activeQuery, !query.isEmpty else { return }
        guard !loadingTabs.contains(tab) else { return }
        let token = webSocketService.token
        guard !token.isEmpty else { return }
        loadingTabs.insert(tab)
        searchService.searchMessages(token: token,
                                     query: query,
                                     tab: tab,
                                     cursor: cursor,
                                     cancelExisting: false) { [weak self] outcome in
            guard let self = self else { return }
            self.loadingTabs.remove(tab)
            guard self.activeQueryMatches(query) else { return }
            switch outcome {
            case .success(let unified):
                self.processRemoteResults(unified, query: query, focusedTab: tab, appending: true)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func unifiedTab(for filter: Filter) -> UnifiedSearchTab? {
        switch filter {
        case .all, .messages:
            return .messages
        case .links:
            return .links
        case .files:
            return .files
        case .pins:
            return .pins
        case .media:
            return .media
        case .people:
            return nil
        }
    }
    
    private func localResults(for query: String) -> SearchResults {
        let lowered = query.lowercased()
        var aggregate = SearchResults()
        aggregate.messages = localMessagesMatching(query: query, limit: 20)
        aggregate.people = suggestedPeople(limit: 30, query: lowered)
        return aggregate
    }
    
    private func localMessagesMatching(query: String?, limit: Int) -> [MessageResult] {
        let sourceMessages: [Message]
        if let query = query, !query.isEmpty {
            let lowered = query.lowercased()
            sourceMessages = webSocketService.data.filter { message in
                message.content.lowercased().contains(lowered)
            }
        } else {
            sourceMessages = Array(webSocketService.data.suffix(limit).reversed())
        }
        return Array(makeMessageResults(from: sourceMessages, query: query ?? "", origin: .local).prefix(limit))
    }
    
    private func mergeMessages(_ local: [MessageResult], with remote: [MessageResult]) -> [MessageResult] {
        var combined: [String: MessageResult] = [:]
        for item in local { combined[item.id] = item }
        for item in remote { combined[item.id] = item }
        return combined.values.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
    }
    
    private func makeMessageResults(from messages: [Message], query: String?, origin: MessageResult.Origin) -> [MessageResult] {
        var seen = Set<String>()
        return messages.compactMap { message in
            guard !seen.contains(message.messageId) else { return nil }
            seen.insert(message.messageId)
            let context = messageContext(for: message)
            let preview = previewText(for: message)
            let normalizedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
            let highlight = normalizedQuery.flatMap { highlightRanges(in: preview, query: $0) } ?? []
            let timestamp = message.timestamp.flatMap { isoFormatter.date(from: $0) }
            return MessageResult(message: message,
                                 context: context,
                                 preview: preview,
                                 highlightRanges: highlight,
                                 timestamp: timestamp,
                                 origin: origin)
        }
    }
    
    private func suggestedPeople(limit: Int, query: String? = nil) -> [UserResult] {
        var map: [String: UserResult] = [:]
        for dm in webSocketService.dms {
            let context: UserResult.Context = dm.type == 3 ? .groupDM : .directMessage
            for user in dm.recipients ?? [] {
                let result = UserResult(user: user,
                                        context: context,
                                        dmChannelId: dm.id)
                map[user.id] = result
            }
        }
        var people = Array(map.values).sorted { $0.displayName < $1.displayName }
        if let query = query, !query.isEmpty {
            people = people.filter { $0.matches(query) }
        }
        return Array(people.prefix(limit))
    }
    
    private func messageContext(for message: Message) -> MessageContext {
        if let dm = dmDictionary[message.channelId] {
            let iconSource: MessageContext.IconSource
            if dm.type == 3 {
                iconSource = .group(dm.recipients ?? [])
            } else {
                iconSource = .user(dm.recipients?.first)
            }
            return MessageContext(channelId: message.channelId,
                                  title: dm.displayName,
                                  subtitle: dm.subtitle,
                                  iconSource: iconSource,
                                  guild: nil,
                                  guildName: nil,
                                  isDirectMessage: true)
        }
        if let channelContext = channelDictionary[message.channelId] {
            return MessageContext(channelId: message.channelId,
                                  title: channelContext.channel.displayName,
                                  subtitle: channelContext.subtitle,
                                  iconSource: .channel,
                                  guild: channelContext.guild,
                                  guildName: channelContext.guild?.name,
                                  isDirectMessage: false)
        }
        let fallbackTitle: String
        if message.guildId == nil {
            fallbackTitle = "Direct Message"
        } else {
            let identifier = message.channelId
            let prefix = identifier.prefix(6)
            fallbackTitle = "#\(prefix)…"
        }
        return MessageContext(channelId: message.channelId,
                              title: fallbackTitle,
                              subtitle: message.guildId == nil ? "Direct Message" : "Unknown Channel",
                              iconSource: .channel,
                              guild: nil,
                              guildName: nil,
                              isDirectMessage: message.guildId == nil)
    }
    
    private func previewText(for message: Message) -> String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let attachments = message.attachments, !attachments.isEmpty {
            return "\(attachments.count) attachment\(attachments.count > 1 ? "s" : "")"
        }
        if let embeds = message.embeds, !embeds.isEmpty {
            return "Embedded content"
        }
        return "(No text content)"
    }
    
    private func highlightRanges(in text: String, query: String) -> [Range<String.Index>] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: trimmed, options: [.caseInsensitive], range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<text.endIndex
        }
        return ranges
    }
    
    private var dmDictionary: [String: DMs] {
        Dictionary(uniqueKeysWithValues: webSocketService.dms.map { ($0.id, $0) })
    }
    
    private var channelDictionary: [String: ChannelContext] {
        let guildLookup = Dictionary(uniqueKeysWithValues: webSocketService.Guilds.map { ($0.id, $0) })
        var map: [String: ChannelContext] = [:]
        for category in webSocketService.channels {
            for channel in category.channels {
                let guild = channel.guildId.flatMap { guildLookup[$0] }
                let subtitle: String?
                if let categoryName = category.name, !categoryName.isEmpty {
                    subtitle = guild != nil ? "\(categoryName) • \(guild!.name)" : categoryName
                } else {
                    subtitle = guild?.name
                }
                map[channel.id] = ChannelContext(channel: channel, subtitle: subtitle, guild: guild)
            }
        }
        return map
    }
}

struct SearchResults {
    var messages: [MessageResult] = []
    var links: [MessageResult] = []
    var files: [MessageResult] = []
    var pins: [MessageResult] = []
    var media: [MessageResult] = []
    var people: [UserResult] = []
    
    var isEmpty: Bool {
        messages.isEmpty && links.isEmpty && files.isEmpty && pins.isEmpty && media.isEmpty && people.isEmpty
    }
}

struct MessageResult: Identifiable {
    enum Origin {
        case local
        case remote
    }
    
    let message: Message
    let context: MessageContext
    let preview: String
    let highlightRanges: [Range<String.Index>]
    let timestamp: Date?
    let origin: Origin
    
    var id: String { message.messageId }
}

struct UserResult: Identifiable {
    enum Context {
        case directMessage
        case groupDM
    }
    
    let user: User
    let context: Context
    let dmChannelId: String?
    
    var id: String { user.id }
    var displayName: String { user.global_name ?? user.username }
    var subtitle: String {
        switch context {
        case .directMessage:
            return "Direct message"
        case .groupDM:
            return "Group DM"
        }
    }
    
    func matches(_ query: String) -> Bool {
        let lowered = query.lowercased()
        return displayName.lowercased().contains(lowered) || user.username.lowercased().contains(lowered)
    }
}

struct MessageContext {
    enum IconSource {
        case user(User?)
        case group([User])
        case channel
    }
    
    let channelId: String
    let title: String
    let subtitle: String?
    let iconSource: IconSource
    let guild: Guild?
    let guildName: String?
    let isDirectMessage: Bool
}

private struct ChannelContext {
    let channel: Channel
    let subtitle: String?
    let guild: Guild?
}

private extension DMs {
    var displayName: String {
        if type == 1, let recipient = recipients?.first {
            return recipient.global_name ?? recipient.username
        }
        let names = recipients?.prefix(3).compactMap { $0.global_name ?? $0.username } ?? []
        if names.isEmpty { return "Group DM" }
        if names.count < 3 {
            return names.joined(separator: ", ")
        }
        let extraCount = (recipients?.count ?? 0) - names.count
        if extraCount > 0 {
            return names.joined(separator: ", ") + " +\(extraCount)"
        } else {
            return names.joined(separator: ", ")
        }
    }
    
    var subtitle: String {
        switch type {
        case 1:
            return "Direct Message"
        case 3:
            let count = recipients?.count ?? 0
            return "Group DM • \(count) member\(count == 1 ? "" : "s")"
        default:
            return "Conversation"
        }
    }
}
