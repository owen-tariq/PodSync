import Foundation

/// Manages podcast search, subscriptions, episode downloads, listened tracking,
/// and syncing episodes to the iPod (with per-show retention).
@MainActor
final class PodcastManager: ObservableObject {
    static let shared = PodcastManager()

    @Published private(set) var subscriptions: [PodcastSubscription] = []
    /// Episodes per feed URL, populated by refresh()
    @Published private(set) var episodesByFeed: [String: [PodcastEpisode]] = [:]
    /// GUIDs of episodes the user has listened to (or marked as such)
    @Published private(set) var listenedGuids: Set<String> = []
    /// GUIDs currently downloading → progress 0...1 (indeterminate = 0)
    @Published private(set) var downloading: Set<String> = []
    @Published var lastError: String?

    private let fileManager = FileManager.default

    // MARK: - Storage

    private var appSupportDir: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PodSync", isDirectory: true)
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private var subscriptionsFile: URL { appSupportDir.appendingPathComponent("podcasts.json") }
    private var listenedFile: URL { appSupportDir.appendingPathComponent("listened.json") }

    var downloadsDir: URL {
        let dir = appSupportDir.appendingPathComponent("Podcasts", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: subscriptionsFile),
           let decoded = try? JSONDecoder().decode([PodcastSubscription].self, from: data) {
            subscriptions = decoded
        }
        if let data = try? Data(contentsOf: listenedFile),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            listenedGuids = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(subscriptions) {
            try? data.write(to: subscriptionsFile)
        }
        if let data = try? JSONEncoder().encode(listenedGuids) {
            try? data.write(to: listenedFile)
        }
    }

    // MARK: - Search (iTunes Search API)

    func search(term: String) async -> [PodcastSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "limit", value: "30")
        ]
        guard let url = components.url else { return [] }

        struct ITunesResponse: Codable {
            struct Item: Codable {
                var collectionName: String?
                var artistName: String?
                var feedUrl: String?
                var artworkUrl600: String?
                var artworkUrl100: String?
                var trackCount: Int?
                var primaryGenreName: String?
            }
            var results: [Item]
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ITunesResponse.self, from: data)
            return decoded.results.compactMap { item in
                guard let feed = item.feedUrl, let title = item.collectionName else { return nil }
                return PodcastSearchResult(
                    title: title,
                    author: item.artistName,
                    feedURL: feed,
                    artworkURL: item.artworkUrl600 ?? item.artworkUrl100,
                    episodeCount: item.trackCount,
                    genre: item.primaryGenreName
                )
            }
        } catch {
            lastError = "Podcast search failed: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Subscriptions

    func isSubscribed(feedURL: String) -> Bool {
        subscriptions.contains { $0.feedURL == feedURL }
    }

    func subscribe(result: PodcastSearchResult) async {
        guard !isSubscribed(feedURL: result.feedURL) else { return }
        let sub = PodcastSubscription(
            feedURL: result.feedURL,
            title: result.title,
            author: result.author,
            artworkURL: result.artworkURL,
            showDescription: nil
        )
        subscriptions.append(sub)
        persist()
        await refresh(feedURL: result.feedURL)
    }

    /// Subscribe directly by RSS feed URL.
    func subscribe(feedURL: String) async -> Bool {
        let trimmed = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubscribed(feedURL: trimmed), let url = URL(string: trimmed) else { return false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let parsed = PodcastFeedParser.parse(data: data, feedURL: trimmed) else {
                lastError = "That URL doesn't look like a podcast RSS feed."
                return false
            }
            let sub = PodcastSubscription(
                feedURL: trimmed,
                title: parsed.title.isEmpty ? trimmed : parsed.title,
                author: parsed.author,
                artworkURL: parsed.artworkURL,
                showDescription: parsed.description
            )
            subscriptions.append(sub)
            episodesByFeed[trimmed] = parsed.episodes
            persist()
            return true
        } catch {
            lastError = "Could not load feed: \(error.localizedDescription)"
            return false
        }
    }

    func unsubscribe(feedURL: String) {
        subscriptions.removeAll { $0.feedURL == feedURL }
        episodesByFeed[feedURL] = nil
        persist()
    }

    func setRetention(feedURL: String, keepLatest: Int?) {
        guard let idx = subscriptions.firstIndex(where: { $0.feedURL == feedURL }) else { return }
        subscriptions[idx].keepLatest = keepLatest
        persist()
    }

    // MARK: - Refresh

    func refresh(feedURL: String) async {
        guard let url = URL(string: feedURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let parsed = PodcastFeedParser.parse(data: data, feedURL: feedURL) {
                episodesByFeed[feedURL] = parsed.episodes
                // Update show metadata opportunistically
                if let idx = subscriptions.firstIndex(where: { $0.feedURL == feedURL }) {
                    if subscriptions[idx].showDescription == nil { subscriptions[idx].showDescription = parsed.description }
                    if subscriptions[idx].artworkURL == nil { subscriptions[idx].artworkURL = parsed.artworkURL }
                    persist()
                }
            }
        } catch {
            lastError = "Could not refresh \(feedURL): \(error.localizedDescription)"
        }
    }

    func refreshAll() async {
        for sub in subscriptions {
            await refresh(feedURL: sub.feedURL)
        }
    }

    // MARK: - Downloads

    /// Local file location for a downloaded episode (nil if not downloaded).
    func localFile(for episode: PodcastEpisode) -> URL? {
        let url = downloadLocation(for: episode)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func downloadLocation(for episode: PodcastEpisode) -> URL {
        let showDir = downloadsDir.appendingPathComponent(sanitize(episode.showTitle), isDirectory: true)
        try? fileManager.createDirectory(at: showDir, withIntermediateDirectories: true)
        let ext = URL(string: episode.enclosureURL)?.pathExtension.split(separator: "?").first.map(String.init) ?? "mp3"
        let safeExt = ext.isEmpty ? "mp3" : ext
        return showDir.appendingPathComponent(sanitize(episode.title)).appendingPathExtension(safeExt)
    }

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    /// Download an episode's audio file. Returns the local URL on success.
    @discardableResult
    func download(episode: PodcastEpisode) async -> URL? {
        if let existing = localFile(for: episode) { return existing }
        guard let remote = URL(string: episode.enclosureURL) else { return nil }

        downloading.insert(episode.guid)
        defer { downloading.remove(episode.guid) }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: remote)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                lastError = "Download failed (\(http.statusCode)) for \(episode.title)"
                return nil
            }
            let dest = downloadLocation(for: episode)
            try? fileManager.removeItem(at: dest)
            try fileManager.moveItem(at: tempURL, to: dest)
            return dest
        } catch {
            lastError = "Download failed for \(episode.title): \(error.localizedDescription)"
            return nil
        }
    }

    func deleteDownload(episode: PodcastEpisode) {
        if let file = localFile(for: episode) {
            try? fileManager.removeItem(at: file)
            objectWillChange.send()
        }
    }

    // MARK: - Listened tracking

    func markListened(_ episode: PodcastEpisode, listened: Bool = true) {
        if listened {
            listenedGuids.insert(episode.guid)
        } else {
            listenedGuids.remove(episode.guid)
        }
        persist()
    }

    func isListened(_ episode: PodcastEpisode) -> Bool {
        listenedGuids.contains(episode.guid)
    }

    // MARK: - Sync to iPod

    /// Whether an episode is already on the device (matched by episode URL or title+show).
    func isOnDevice(_ episode: PodcastEpisode, ipodManager: IPodManager) -> Bool {
        ipodManager.deviceTracks.contains { track in
            guard track.ipodMediaType == 4 else { return false }
            if let feed = track.podcastFeedURL, feed == episode.feedURL,
               track.title == episode.title {
                return true
            }
            return track.title == episode.title && track.album == episode.showTitle
        }
    }

    /// Download (if needed) and sync one episode to the iPod as a podcast.
    /// Returns true on success. Does NOT save the DB — callers batch + save.
    func syncEpisode(_ episode: PodcastEpisode, to ipodManager: IPodManager) async -> Bool {
        guard !isOnDevice(episode, ipodManager: ipodManager) else { return true }
        guard let file = await download(episode: episode) else { return false }

        let attrs = try? fileManager.attributesOfItem(atPath: file.path)
        let size = (attrs?[.size] as? Int64) ?? episode.fileSize ?? 0

        // Fetch show artwork for the episode (resized per the artwork setting)
        var artworkData: Data? = nil
        if let sub = subscriptions.first(where: { $0.feedURL == episode.feedURL }),
           let artURLString = sub.artworkURL,
           let artURL = URL(string: artURLString) {
            artworkData = try? await URLSession.shared.data(from: artURL).0
        }
        if let data = artworkData {
            artworkData = ArtworkResizer.resizeToSetting(data)
            ArtworkCache.shared.storeToDisk(data: artworkData, album: episode.showTitle)
        }

        let meta = PodcastTrackMeta(
            episodeURL: episode.enclosureURL,
            feedURL: episode.feedURL,
            description: episode.episodeDescription,
            subtitle: episode.episodeDescription.map { String($0.prefix(255)) },
            releaseDate: episode.pubDate,
            markUnplayed: !isListened(episode)
        )

        let year = episode.pubDate.map { Calendar.current.component(.year, from: $0) }

        return ipodManager.addTrack(
            filePath: file.path,
            title: episode.title,
            artist: subscriptions.first(where: { $0.feedURL == episode.feedURL })?.author ?? episode.showTitle,
            album: episode.showTitle,
            artworkData: artworkData,
            duration: episode.duration ?? 0,
            size: size,
            year: year,
            trackNum: nil,
            discNum: nil,
            genre: "Podcast",
            mediaTypeOverride: 4,
            podcastMeta: meta
        )
    }

    /// Sync the latest episodes of a subscription to the iPod, applying retention.
    /// Returns (added, removed) counts.
    func syncSubscription(_ sub: PodcastSubscription, to ipodManager: IPodManager, latest: Int = 5) async -> (added: Int, removed: Int) {
        if episodesByFeed[sub.feedURL] == nil {
            await refresh(feedURL: sub.feedURL)
        }
        guard let episodes = episodesByFeed[sub.feedURL], !episodes.isEmpty else { return (0, 0) }

        let sorted = episodes.sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
        let toSync = Array(sorted.prefix(max(1, latest)))

        var added = 0
        for episode in toSync {
            if !isOnDevice(episode, ipodManager: ipodManager) {
                if await syncEpisode(episode, to: ipodManager) {
                    added += 1
                }
            }
        }

        // Retention: remove old episodes of this show beyond keepLatest
        var removed = 0
        if let keep = sub.keepLatest, keep > 0 {
            let deviceEpisodes = ipodManager.deviceTracks
                .filter { $0.ipodMediaType == 4 && ($0.podcastFeedURL == sub.feedURL || $0.album == sub.title) }
                .map { (id: $0.id, releaseDate: $0.releaseDate) }
            let removals = PodcastRetention.episodesToRemove(deviceEpisodes: deviceEpisodes, keepLatest: keep)
            if !removals.isEmpty {
                _ = ipodManager.deleteTracks(ids: Set(removals))
                removed = removals.count
            }
        }

        ipodManager.save()
        ipodManager.reloadTracks()
        return (added, removed)
    }
}
