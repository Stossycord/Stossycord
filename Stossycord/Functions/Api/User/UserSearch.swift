import Foundation

enum UnifiedSearchTab: String, CaseIterable {
    case messages
    case links
    case files
    case pins
    case media
}

@discardableResult
func UserSearch(token: String,
                query: String,
                tab: UnifiedSearchTab? = nil,
                cursor: SearchCursor? = nil,
                limit: Int? = nil,
                completion: @escaping (Result<UnifiedSearchResults, Error>) -> Void) -> URLSessionDataTask? {
    guard let request = makeUnifiedSearchRequest(token: token, query: query, tab: tab, cursor: cursor, limit: limit) else {
        return nil
    }
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error as NSError?, error.code == NSURLErrorCancelled {
            return
        }
        if let error = error {
            Task { @MainActor in 
                completion(.failure(error))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            Task { @MainActor in 
                completion(.failure(SearchServiceError.invalidResponse))
            }
            return
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            Task { @MainActor in 
                completion(.failure(SearchServiceError.http(status: httpResponse.statusCode, message: message)))
            }
            return
        }
        guard let data = data else {
            Task { @MainActor in 
                completion(.failure(SearchServiceError.emptyPayload))
            }
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(UnifiedSearchResponse.self, from: data)
            let unified = UnifiedSearchResults(tabs: payload.tabs)
            Task { @MainActor in 
                completion(.success(unified))
            }
        } catch {
            Task { @MainActor in 
                completion(.failure(error))
            }
        }
    }
    return task
}

private func makeUnifiedSearchRequest(token: String,
                                      query: String,
                                      tab: UnifiedSearchTab?,
                                      cursor: SearchCursor?,
                                      limit: Int?) -> URLRequest? {
    guard let url = URL(string: "https://discord.com/api/v9/users/@me/messages/search/tabs") else {
        return nil
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(token, forHTTPHeaderField: "Authorization")
    request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("https://discord.com", forHTTPHeaderField: "Origin")
    request.addValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.addValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.addValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    let deviceInfo = CurrentDeviceInfo.shared.deviceInfo
    let timeZone = CurrentDeviceInfo.shared.currentTimeZone
    let locale = CurrentDeviceInfo.shared.Country
    request.addValue(deviceInfo.browserUserAgent, forHTTPHeaderField: "User-Agent")
    request.addValue("bugReporterEnabled", forHTTPHeaderField: "X-Debug-Options")
    request.addValue("\(timeZone.identifier)-\(locale)", forHTTPHeaderField: "X-Discord-Locale")
    request.addValue(timeZone.identifier, forHTTPHeaderField: "X-Discord-Timezone")
    request.addValue(deviceInfo.toBase64() ?? "base64", forHTTPHeaderField: "X-Super-Properties")
    let normalizedQuery = query.replacingOccurrences(of: "\\", with: "")
    let payload = TabsSearchRequest(content: normalizedQuery,
                                    focusedTab: tab,
                                    cursor: cursor,
                                    limitOverride: limit)
    let encoder = JSONEncoder()
    encoder.outputFormatting = []
    do {
        request.httpBody = try encoder.encode(payload)
    } catch {
        return nil
    }
    return request
}

private struct TabsSearchRequest: Encodable {
    struct CursorPayload: Encodable {
        let timestamp: String
        let type: String
    }
    
    struct TabPayload: Encodable {
        let sortBy: String
        let sortOrder: String
        let content: String
        let cursor: CursorPayload?
        let limit: Int
        let has: [String]?
        let pinned: Bool?
        
        enum CodingKeys: String, CodingKey {
            case sortBy = "sort_by"
            case sortOrder = "sort_order"
            case content
            case cursor
            case limit
            case has
            case pinned
        }
    }
    
    struct TabsContainer: Encodable {
        let messages: TabPayload?
        let links: TabPayload?
        let files: TabPayload?
        let pins: TabPayload?
        let media: TabPayload?
    }
    
    private struct TabDescriptor {
        let has: [String]?
        let pinned: Bool?
        let limit: Int
    }
    
    let tabs: TabsContainer
    let trackExactTotalHits: Bool
    
    enum CodingKeys: String, CodingKey {
        case tabs
        case trackExactTotalHits = "track_exact_total_hits"
    }
    
    init(content: String, focusedTab: UnifiedSearchTab?, cursor: SearchCursor?, limitOverride: Int?) {
        self.trackExactTotalHits = false
        func descriptor(for tab: UnifiedSearchTab) -> TabDescriptor {
            switch tab {
            case .messages:
                return TabDescriptor(has: nil, pinned: nil, limit: 15)
            case .links:
                return TabDescriptor(has: ["link"], pinned: nil, limit: 10)
            case .files:
                return TabDescriptor(has: ["file"], pinned: nil, limit: 10)
            case .pins:
                return TabDescriptor(has: nil, pinned: true, limit: 15)
            case .media:
                return TabDescriptor(has: ["image", "video"], pinned: nil, limit: 15)
            }
        }
        func requestCursor(for tab: UnifiedSearchTab) -> CursorPayload? {
            guard let cursor = cursor,
                  let timestamp = cursor.timestamp, !timestamp.isEmpty,
                  let type = cursor.type, !type.isEmpty,
                  focusedTab == tab else { return nil }
            return CursorPayload(timestamp: timestamp, type: type)
        }
        func payload(for tab: UnifiedSearchTab) -> TabPayload? {
            if let focused = focusedTab, focused != tab {
                return nil
            }
            let descriptor = descriptor(for: tab)
            let limit = limitOverride ?? descriptor.limit
            return TabPayload(sortBy: "timestamp",
                              sortOrder: "desc",
                              content: content,
                              cursor: requestCursor(for: tab),
                              limit: limit,
                              has: descriptor.has,
                              pinned: descriptor.pinned)
        }
        tabs = TabsContainer(messages: payload(for: .messages),
                             links: payload(for: .links),
                             files: payload(for: .files),
                             pins: payload(for: .pins),
                             media: payload(for: .media))
    }
}

struct UnifiedSearchResponse: Decodable {
    let tabs: TabsResult?
}

struct TabsResult: Decodable {
    let messages: TabResult?
    let media: TabResult?
    let pins: TabResult?
    let links: TabResult?
    let files: TabResult?
}

struct TabResult: Decodable {
    let messages: [[Message]]?
    let channels: [DMs]?
    let totalResults: Int?
    let timeSpentMs: Int?
    let cursor: SearchCursor?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case channels
        case totalResults = "total_results"
        case timeSpentMs = "time_spent_ms"
        case cursor
    }
}

struct SearchCursor: Codable {
    let timestamp: String?
    let type: String?
}

struct UnifiedSearchResults {
    let messages: [Message]
    let media: [Message]
    let pins: [Message]
    let links: [Message]
    let files: [Message]
    let channels: [DMs]
    private let tabDetails: [UnifiedSearchTab: TabDetails]
    
    struct TabDetails {
        let cursor: SearchCursor?
        let totalResults: Int?
        let channels: [DMs]
    }
    
    static let empty = UnifiedSearchResults(messages: [],
                                            media: [],
                                            pins: [],
                                            links: [],
                                            files: [],
                                            channels: [],
                                            tabDetails: [:])
    
    init(messages: [Message],
         media: [Message],
         pins: [Message],
         links: [Message],
         files: [Message],
         channels: [DMs],
         tabDetails: [UnifiedSearchTab: TabDetails] = [:]) {
        self.messages = messages
        self.media = media
        self.pins = pins
        self.links = links
        self.files = files
        self.channels = channels
        self.tabDetails = tabDetails
    }
    
    var allMessages: [Message] {
        var seen: Set<String> = []
        var combined: [Message] = []
        for message in messages + media + pins + links + files {
            if !seen.contains(message.messageId) {
                seen.insert(message.messageId)
                combined.append(message)
            }
        }
        return combined
    }
    
    init(tabs: TabsResult?) {
        guard let tabs = tabs else {
            self = .empty
            return
        }
        var details: [UnifiedSearchTab: TabDetails] = [:]
        func register(_ tab: UnifiedSearchTab, result: TabResult?) -> [Message] {
            guard let result = result else {
                details[tab] = TabDetails(cursor: nil, totalResults: nil, channels: [])
                return []
            }
            details[tab] = TabDetails(cursor: result.cursor,
                                       totalResults: result.totalResults,
                                       channels: result.channels ?? [])
            return UnifiedSearchResults.flattenMessages(result.messages)
        }
        self.messages = register(.messages, result: tabs.messages)
        self.media = register(.media, result: tabs.media)
        self.pins = register(.pins, result: tabs.pins)
        self.links = register(.links, result: tabs.links)
        self.files = register(.files, result: tabs.files)
        self.channels = UnifiedSearchResults.mergeChannels(from: details.values.map { $0.channels })
        self.tabDetails = details
    }
    
    private static func flattenMessages(_ source: [[Message]]?) -> [Message] {
        guard let source = source else { return [] }
        return source.flatMap { $0 }
    }
    
    private static func mergeChannels(from collections: [[DMs]]) -> [DMs] {
        var seen: Set<String> = []
        var result: [DMs] = []
        for collection in collections {
            for channel in collection {
                if !seen.contains(channel.id) {
                    seen.insert(channel.id)
                    result.append(channel)
                }
            }
        }
        return result
    }
    
    func cursor(for tab: UnifiedSearchTab) -> SearchCursor? {
        return tabDetails[tab]?.cursor ?? nil
    }
    
    func totalResults(for tab: UnifiedSearchTab) -> Int? {
        return tabDetails[tab]?.totalResults
    }
}
