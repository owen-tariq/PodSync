import SwiftUI

// MARK: - Podcasts (subscriptions + search + episodes)

struct PodcastsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject private var podcastManager = PodcastManager.shared

    @AppStorage(PodSyncSettings.podcastSyncLatestKey) private var podcastSyncLatest: Int = 5

    @State private var selectedFeed: String? = nil
    @State private var showSearch = false
    @State private var showAddFeed = false
    @State private var addFeedText = ""
    @State private var isRefreshing = false
    @State private var isSyncing = false
    @State private var statusMessage: String? = nil

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if podcastManager.subscriptions.isEmpty {
                emptyState
            } else {
                HSplitView {
                    subscriptionList
                        .frame(minWidth: 260, idealWidth: 300)
                    episodeDetail
                        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            PodcastSearchSheet()
        }
        .alert("Subscribe by RSS URL", isPresented: $showAddFeed) {
            TextField("https://example.com/feed.xml", text: $addFeedText)
            Button("Cancel", role: .cancel) { addFeedText = "" }
            Button("Subscribe") {
                let url = addFeedText
                addFeedText = ""
                Task {
                    if await podcastManager.subscribe(feedURL: url) {
                        statusMessage = "Subscribed!"
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let message = statusMessage ?? podcastManager.lastError {
                Text(message)
                    .font(.caption)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 12)
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        statusMessage = nil
                        podcastManager.lastError = nil
                    }
            }
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 28))
                .foregroundColor(.purple)
            Text("Podcasts")
                .font(.title)
                .fontWeight(.bold)
            Spacer()

            Button {
                showSearch = true
            } label: {
                Label("Search Podcasts", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)

            Button {
                showAddFeed = true
            } label: {
                Label("Add RSS Feed", systemImage: "link")
            }
            .buttonStyle(.bordered)

            Button {
                isRefreshing = true
                Task {
                    await podcastManager.refreshAll()
                    isRefreshing = false
                }
            } label: {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing || podcastManager.subscriptions.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: Subscription list

    private var subscriptionList: some View {
        List(selection: $selectedFeed) {
            ForEach(podcastManager.subscriptions) { sub in
                HStack(spacing: 10) {
                    AsyncImage(url: sub.artworkURL.flatMap { URL(string: $0) }) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.purple.opacity(0.2))
                            .overlay(Image(systemName: "mic").foregroundColor(.purple))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.title)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if let author = sub.author {
                            Text(author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if let keep = sub.keepLatest {
                            Text("Keeps latest \(keep) on iPod")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .tag(sub.feedURL)
                .contextMenu {
                    Menu("Retention on iPod") {
                        Button("Keep all episodes") {
                            podcastManager.setRetention(feedURL: sub.feedURL, keepLatest: nil)
                        }
                        ForEach([3, 5, 10, 25], id: \.self) { n in
                            Button("Keep latest \(n)") {
                                podcastManager.setRetention(feedURL: sub.feedURL, keepLatest: n)
                            }
                        }
                    }
                    Button("Refresh") {
                        Task { await podcastManager.refresh(feedURL: sub.feedURL) }
                    }
                    Divider()
                    Button("Unsubscribe", role: .destructive) {
                        podcastManager.unsubscribe(feedURL: sub.feedURL)
                        if selectedFeed == sub.feedURL { selectedFeed = nil }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: Episode detail

    @ViewBuilder
    private var episodeDetail: some View {
        if let feed = selectedFeed,
           let sub = podcastManager.subscriptions.first(where: { $0.feedURL == feed }) {
            EpisodeListView(subscription: sub, isSyncing: $isSyncing, statusMessage: $statusMessage)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "mic")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Select a show")
                    .font(.title2)
                    .fontWeight(.medium)
                Text("Choose a subscription to browse and sync episodes.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.purple)
            Text("No Podcast Subscriptions")
                .font(.title2)
                .fontWeight(.medium)
            Text("Search the podcast directory or add an RSS feed URL to subscribe.\nEpisodes you sync appear in the Podcasts menu on your iPod.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button {
                    showSearch = true
                } label: {
                    Label("Search Podcasts", systemImage: "magnifyingglass")
                }
                Button {
                    showAddFeed = true
                } label: {
                    Label("Add RSS Feed", systemImage: "link")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Episode list for one show

struct EpisodeListView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject private var podcastManager = PodcastManager.shared
    @AppStorage(PodSyncSettings.podcastSyncLatestKey) private var podcastSyncLatest: Int = 5

    let subscription: PodcastSubscription
    @Binding var isSyncing: Bool
    @Binding var statusMessage: String?

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    private var episodes: [PodcastEpisode] {
        (podcastManager.episodesByFeed[subscription.feedURL] ?? [])
            .sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(episodes.count) episodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    isSyncing = true
                    Task {
                        let result = await podcastManager.syncSubscription(subscription, to: ipodManager, latest: podcastSyncLatest)
                        statusMessage = "Synced \(result.added) new episode\(result.added == 1 ? "" : "s")" + (result.removed > 0 ? ", removed \(result.removed) old" : "")
                        isSyncing = false
                    }
                } label: {
                    if isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Sync Latest \(podcastSyncLatest) to iPod", systemImage: "ipod")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(deviceManager.connectedIPod == nil || isSyncing || episodes.isEmpty)
            }
            .padding(12)

            Divider()

            if episodes.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading episodes...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await podcastManager.refresh(feedURL: subscription.feedURL)
                }
            } else {
                List(episodes) { episode in
                    EpisodeRow(episode: episode)
                }
                .listStyle(.inset)
            }
        }
    }
}

struct EpisodeRow: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject private var podcastManager = PodcastManager.shared

    let episode: PodcastEpisode

    @State private var isWorking = false

    private var ipodManager: IPodManager { deviceManager.ipodManager }
    private var isDownloaded: Bool { podcastManager.localFile(for: episode) != nil }
    private var isListened: Bool { podcastManager.isListened(episode) }
    private var onDevice: Bool { podcastManager.isOnDevice(episode, ipodManager: ipodManager) }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isListened ? Color.clear : Color.blue)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: isListened ? 1 : 0))

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .fontWeight(.medium)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(episode.pubDateFormatted)
                    if let duration = episode.duration, duration > 0 {
                        Text("·")
                        Text(formatDuration(duration))
                    }
                    if isDownloaded {
                        Text("·")
                        Label("Downloaded", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                    }
                    if onDevice {
                        Text("·")
                        Label("On iPod", systemImage: "ipod")
                            .foregroundColor(.accentColor)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if podcastManager.downloading.contains(episode.guid) || isWorking {
                ProgressView().controlSize(.small)
            } else {
                if !isDownloaded {
                    Button {
                        Task { await podcastManager.download(episode: episode) }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Download episode")
                }

                if !onDevice {
                    Button {
                        isWorking = true
                        Task {
                            if await podcastManager.syncEpisode(episode, to: ipodManager) {
                                ipodManager.save()
                                ipodManager.reloadTracks()
                            }
                            isWorking = false
                        }
                    } label: {
                        Image(systemName: "plus.rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .help("Sync to iPod")
                    .disabled(deviceManager.connectedIPod == nil)
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(isListened ? "Mark as Unplayed" : "Mark as Played") {
                podcastManager.markListened(episode, listened: !isListened)
            }
            if isDownloaded {
                Button("Delete Download", role: .destructive) {
                    podcastManager.deleteDownload(episode: episode)
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Podcast search sheet

struct PodcastSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var podcastManager = PodcastManager.shared

    @State private var searchTerm = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var isSearching = false
    @State private var subscribingFeed: String? = nil
    @State private var previewResult: PodcastSearchResult? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search podcasts...", text: $searchTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { runSearch() }
                Button("Search") { runSearch() }
                    .disabled(searchTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Done") { dismiss() }
            }
            .padding(12)

            Divider()

            if isSearching {
                VStack {
                    ProgressView()
                    Text("Searching the podcast directory...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Search for shows by name, topic, or host")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { result in
                    HStack(spacing: 10) {
                        AsyncImage(url: result.artworkURL.flatMap { URL(string: $0) }) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.2))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title).fontWeight(.medium).lineLimit(1)
                            HStack(spacing: 6) {
                                if let author = result.author {
                                    Text(author).lineLimit(1)
                                }
                                if let genre = result.genre {
                                    Text("· \(genre)")
                                }
                                if let count = result.episodeCount {
                                    Text("· \(count) eps")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Episodes") {
                            previewResult = result
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help("Browse episodes without subscribing")

                        if podcastManager.isSubscribed(feedURL: result.feedURL) {
                            Label("Subscribed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else if subscribingFeed == result.feedURL {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Subscribe") {
                                subscribingFeed = result.feedURL
                                Task {
                                    await podcastManager.subscribe(result: result)
                                    subscribingFeed = nil
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        previewResult = result
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 620, height: 480)
        .sheet(item: $previewResult) { result in
            PodcastPreviewSheet(result: result)
        }
    }

    private func runSearch() {
        isSearching = true
        Task {
            results = await podcastManager.search(term: searchTerm)
            isSearching = false
        }
    }
}

// MARK: - Episode preview (browse without subscribing)

struct PodcastPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject private var podcastManager = PodcastManager.shared

    let result: PodcastSearchResult

    @State private var episodes: [PodcastEpisode] = []
    @State private var isLoading = true
    @State private var subscribing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AsyncImage(url: result.artworkURL.flatMap { URL(string: $0) }) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.2))
                        .overlay(Image(systemName: "mic").foregroundColor(.purple))
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(1)
                    if let author = result.author {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Text("\(episodes.count) episodes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if podcastManager.isSubscribed(feedURL: result.feedURL) {
                    Label("Subscribed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else if subscribing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Subscribe") {
                        subscribing = true
                        Task {
                            await podcastManager.subscribe(result: result)
                            subscribing = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Done") { dismiss() }
            }
            .padding(12)

            Divider()

            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading episodes...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if episodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Couldn't load this feed")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(episodes) { episode in
                    EpisodeRow(episode: episode)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 620, height: 480)
        .task {
            episodes = await podcastManager.previewEpisodes(feedURL: result.feedURL)
                .sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
            isLoading = false
        }
    }
}
