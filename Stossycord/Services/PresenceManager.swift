import Foundation
import Combine
import MusicKit
import MediaPlayer

final class PresenceManager: ObservableObject {
    private enum PreferenceKeys {
        static let musicPresenceEnabled = "app.stossycord.presence.musicEnabled"
        static let customName = "app.stossycord.presence.customName"
        static let customDetails = "app.stossycord.presence.customDetails"
        static let customState = "app.stossycord.presence.customState"
    }

    private let webSocketService: WebSocketService
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    private let defaults: UserDefaults

    @Published private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published private(set) var isRequestingAuthorization: Bool = false
    @Published var musicPresenceEnabled: Bool {
        didSet {
            guard musicPresenceEnabled != oldValue else { return }
            defaults.set(musicPresenceEnabled, forKey: PreferenceKeys.musicPresenceEnabled)
            ensurePresenceMatchesMode()
        }
    }
    @Published var customPresenceName: String {
        didSet {
            guard customPresenceName != oldValue else { return }
            defaults.set(customPresenceName, forKey: PreferenceKeys.customName)
            handleCustomPresenceChange()
        }
    }
    @Published var customPresenceDetails: String {
        didSet {
            guard customPresenceDetails != oldValue else { return }
            defaults.set(customPresenceDetails, forKey: PreferenceKeys.customDetails)
            handleCustomPresenceChange()
        }
    }
    @Published var customPresenceState: String {
        didSet {
            guard customPresenceState != oldValue else { return }
            defaults.set(customPresenceState, forKey: PreferenceKeys.customState)
            handleCustomPresenceChange()
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var lastTrackIdentifier: String?
    private var customPresenceActive = false
    private var isActive: Bool = false
    private var presenceTask: Task<Void, Never>?
    private var artworkCache: [String: URL] = [:]
    private let cacheQueue = DispatchQueue(label: "app.stossycord.musicPresence.artworkCache", qos: .utility)

    init(webSocketService: WebSocketService, defaults: UserDefaults = .standard) {
        self.webSocketService = webSocketService
        self.defaults = defaults
        self.musicPresenceEnabled = defaults.object(forKey: PreferenceKeys.musicPresenceEnabled) as? Bool ?? false
        self.customPresenceName = defaults.string(forKey: PreferenceKeys.customName) ?? ""
        self.customPresenceDetails = defaults.string(forKey: PreferenceKeys.customDetails) ?? ""
        self.customPresenceState = defaults.string(forKey: PreferenceKeys.customState) ?? ""
        self.authorizationStatus = MusicAuthorization.currentStatus

        observeConnection()
        observeUserSettings()
        observePlaybackChanges()
    }

    func start() {
        refreshAuthorizationStatus()
    }

    func requestAuthorization() {
        guard !isRequestingAuthorization else { return }

        Task {
            await MainActor.run {
                self.isRequestingAuthorization = true
            }

            let status = await MusicAuthorization.request()

            await MainActor.run {
                self.isRequestingAuthorization = false
                self.applyAuthorizationStatus(status, forceUpdate: true)
            }
        }
    }

    func refreshAuthorizationStatus() {
        applyAuthorizationStatus(MusicAuthorization.currentStatus, forceUpdate: true)
    }

    private func applyAuthorizationStatus(_ status: MusicAuthorization.Status, forceUpdate: Bool = false) {
        if !forceUpdate && authorizationStatus == status { return }
        authorizationStatus = status
        ensurePresenceMatchesMode()
    }

    private func ensurePresenceMatchesMode() {
        if musicPresenceEnabled {
            guard authorizationStatus == .authorized else {
                clearPresence()
                return
            }
            updatePresence()
        } else {
            sendCustomPresencePayloadIfAvailable()
        }
    }

    private func handleCustomPresenceChange() {
        guard !musicPresenceEnabled else { return }
        sendCustomPresencePayloadIfAvailable()
    }

    private func observeConnection() {
        webSocketService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self else { return }
                self.isActive = connected
                if connected {
                    self.ensurePresenceMatchesMode()
                } else {
                    self.stopTimer()
                }
            }
            .store(in: &cancellables)
    }

    private func observeUserSettings() {
        webSocketService.$userSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.ensurePresenceMatchesMode()
            }
            .store(in: &cancellables)
    }

    private func observePlaybackChanges() {
        musicPlayer.beginGeneratingPlaybackNotifications()
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.updatePresence()
        }
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.updatePresence()
        }
    }

    private func updatePresence() {
        guard isActive else { return }

        guard musicPresenceEnabled else {
            sendCustomPresencePayloadIfAvailable()
            return
        }

        guard authorizationStatus == .authorized else {
            clearPresence()
            return
        }

        let state = musicPlayer.playbackState
        guard state == .playing, let item = musicPlayer.nowPlayingItem else {
            clearPresence()
            return
        }

        let storeID = item.playbackStoreID
        guard !storeID.isEmpty else {
            clearPresence()
            return
        }

        let elapsed = max(0, musicPlayer.currentPlaybackTime)
        let duration = item.playbackDuration
        presenceTask?.cancel()
        let storeIDCopy = storeID

        presenceTask = Task { [weak self] in
            guard let self else { return }
            let metadata = await self.metadata(for: item, storeID: storeIDCopy)
            if Task.isCancelled {
                await MainActor.run { self.presenceTask = nil }
                return
            }
            await MainActor.run {
                self.sendMusicPresencePayload(
                    metadata: metadata,
                    storeID: storeIDCopy,
                    elapsed: elapsed,
                    duration: duration
                )
                self.presenceTask = nil
            }
        }
    }

    private func clearPresence(force: Bool = false) {
        stopTimer()
        presenceTask?.cancel()
        presenceTask = nil

        guard isActive else {
            lastTrackIdentifier = nil
            customPresenceActive = false
            return
        }

        guard force || lastTrackIdentifier != nil || customPresenceActive else { return }

        sendPresenceUpdate(with: baseActivities())
        lastTrackIdentifier = nil
        customPresenceActive = false
    }

    private func sendMusicPresencePayload(metadata: SongMetadata, storeID: String, elapsed: TimeInterval, duration: TimeInterval) {
        let now = Date()
        var activities = baseActivities()

        var activity: [String: Any] = [
            "name": "Apple Music",
            "type": 2,
            "details": metadata.title,
            "state": metadata.artist,
            "metadata": ["apple_music_track_id": storeID]
        ]

        if duration > 0 {
            let clampedElapsed = min(max(0, elapsed), duration)
            let startDate = now.addingTimeInterval(-clampedElapsed)
            let endDate = startDate.addingTimeInterval(duration)
            activity["timestamps"] = [
                "start": Int(startDate.timeIntervalSince1970 * 1000),
                "end": Int(endDate.timeIntervalSince1970 * 1000)
            ]
        }

        if let artwork = metadata.artworkURL {
            activity["assets"] = [
                "large_image": "mp:external:\(artwork.absoluteString)",
                "large_text": metadata.album.isEmpty ? metadata.title : metadata.album
            ]
        } else if !metadata.album.isEmpty {
            activity["assets"] = [
                "large_text": metadata.album
            ]
        }

        activities.insert(activity, at: 0)

        sendPresenceUpdate(with: activities, timestamp: now)
        lastTrackIdentifier = storeID
        customPresenceActive = false
        startTimer()
    }

    private func sendCustomPresencePayloadIfAvailable() {
        stopTimer()
        presenceTask?.cancel()
        presenceTask = nil

        let trimmedName = customPresenceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = customPresenceDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedState = customPresenceState.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            let wasCustom = customPresenceActive
            customPresenceActive = false
            if wasCustom || lastTrackIdentifier != nil {
                clearPresence(force: wasCustom)
            }
            return
        }

        guard isActive else { return }

        var activity: [String: Any] = [
            "name": trimmedName,
            "type": 0
        ]

        if !trimmedDetails.isEmpty {
            activity["details"] = trimmedDetails
        }

        if !trimmedState.isEmpty {
            activity["state"] = trimmedState
        }

        var activities = baseActivities()
        activities.insert(activity, at: 0)

        sendPresenceUpdate(with: activities)
        customPresenceActive = true
        lastTrackIdentifier = nil
    }

    private func sendPresenceUpdate(with activities: [[String: Any]], timestamp: Date = Date()) {
        guard isActive else { return }

        let payload: [String: Any] = [
            "op": 3,
            "d": [
                "since": Int(timestamp.timeIntervalSince1970 * 1000),
                "activities": activities,
                "status": webSocketService.userSettings?.status ?? "online",
                "afk": false
            ]
        ]

        webSocketService.sendJSON(payload)
    }

    private func metadata(for item: MPMediaItem, storeID: String) async -> SongMetadata {
        var title = item.title ?? "Unknown Track"
        var artist = item.artist ?? item.albumArtist ?? "Unknown Artist"
        var album = item.albumTitle ?? ""

        if let cached = cachedArtwork(for: storeID) {
            return SongMetadata(title: title, artist: artist, album: album, artworkURL: cached)
        }

        var artworkURL: URL?

        if MusicAuthorization.currentStatus == .authorized {
            do {
                if let song = try await fetchSong(with: storeID) {
                    if !song.title.isEmpty {
                        title = song.title
                    }
                    if !song.artistName.isEmpty {
                        artist = song.artistName
                    }
                    if let albumTitle = song.albumTitle, !albumTitle.isEmpty {
                        album = albumTitle
                    }
                    if let url = song.artwork?.url(width: 512, height: 512) {
                        artworkURL = url
                    }
                }
            } catch {
                if Task.isCancelled {
                    return SongMetadata(title: title, artist: artist, album: album, artworkURL: nil)
                }
                print("MusicPresenceManager: failed to retrieve catalog metadata - \(error.localizedDescription)")
            }
        }

        if let artworkURL {
            storeArtwork(artworkURL, for: storeID)
        }

        return SongMetadata(title: title, artist: artist, album: album, artworkURL: artworkURL)
    }

    private func cachedArtwork(for storeID: String) -> URL? {
        cacheQueue.sync {
            artworkCache[storeID]
        }
    }

    private func storeArtwork(_ url: URL, for storeID: String) {
        cacheQueue.async { [weak self] in
            self?.artworkCache[storeID] = url
        }
    }

    private func fetchSong(with storeID: String) async throws -> Song? {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(storeID))
        let response = try await request.response()
        return response.items.first
    }

    private func baseActivities() -> [[String: Any]] {
        guard let customStatus = webSocketService.userSettings?.customStatus else {
            return []
        }

        if (customStatus.text?.isEmpty ?? true) && customStatus.emojiName == nil {
            return []
        }

        var activity: [String: Any] = [
            "type": 4,
            "state": customStatus.text ?? "",
            "name": "Custom Status",
            "id": "custom"
        ]

        if let emojiName = customStatus.emojiName {
            var emoji: [String: Any] = ["name": emojiName]
            if let emojiId = customStatus.emojiId {
                emoji["id"] = emojiId
            }
            activity["emoji"] = emoji
        }

        return [activity]
    }

    private func startTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshPlayback()
        }
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func refreshPlayback() {
        guard musicPresenceEnabled else { return }
        guard authorizationStatus == .authorized else { return }
        guard isActive else { return }
        updatePresence()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        musicPlayer.endGeneratingPlaybackNotifications()
        presenceTask?.cancel()
        updateTimer?.invalidate()
    }
}

private struct SongMetadata {
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
}
