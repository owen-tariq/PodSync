import SwiftUI
import AppKit
import AVFoundation

/// The main iPod songs management view — matching the OG app's layout.
/// Shows all tracks on the iPod with Clean Up / Refresh / Eject toolbar,
/// stats bar, multi-select, right-click context menu, drag-and-drop add.
struct DeviceSongsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @StateObject private var artworkCache = ArtworkCache.shared
    
    @State private var selectedTracks = Set<TrackModel.ID>()
    @State private var searchText = ""
    @State private var showDeleteAllConfirm = false
    @State private var showDeleteSelectedConfirm = false
    @State private var editingTracks: Set<TrackModel.ID>? = nil
    @State private var showDuplicateFinder = false
    @State private var showTrash = false
    @StateObject private var artworkFixer = ArtworkFixer.shared
    @StateObject private var exporter = IPodExporter.shared
    @State private var searchScope: SearchScope = .all

    enum SearchScope: String, CaseIterable {
        case all = "All", title = "Title", artist = "Artist", album = "Album", genre = "Genre"
    }
    @State private var sortOrder: [KeyPathComparator<TrackModel>] = [
        .init(\.displayArtist), .init(\.displayAlbum), .init(\.displayTitle)
    ]
    
    private var ipodManager: IPodManager {
        deviceManager.ipodManager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header: iPod icon + title + action buttons ──
            headerBar
            
            Divider()
            
            // ── Stats line ──
            statsBar
            
            Divider()
            
            // ── Track table or empty state ──
            if filteredTracks.isEmpty && ipodManager.deviceTracks.isEmpty {
                emptyStateView
            } else if filteredTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                trackTable
            }
        }
        .ipodDropTarget()
        .alert("Delete All Songs?", isPresented: $showDeleteAllConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                let _ = ipodManager.deleteAllTracks()
            }
        } message: {
            Text("This will permanently delete all \(ipodManager.deviceTracks.count) songs from your iPod. This cannot be undone.")
        }
        .alert("Delete Selected Songs?", isPresented: $showDeleteSelectedConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(selectedTracks.count) Songs", role: .destructive) {
                let idsToDelete = selectedTracks
                selectedTracks.removeAll()
                Task { @MainActor in
                    let _ = ipodManager.deleteTracks(ids: idsToDelete)
                }
            }
        } message: {
            Text("This will permanently delete \(selectedTracks.count) selected song(s) from your iPod.")
        }
        .sheet(isPresented: Binding(
            get: { editingTracks != nil },
            set: { if !$0 { editingTracks = nil } }
        )) {
            if let ids = editingTracks {
                EditTrackSheet(trackIds: ids)
            }
        }
        .sheet(isPresented: $showDuplicateFinder) {
            DuplicateFinderSheet()
        }
        .sheet(isPresented: $showTrash) {
            TrashSheet()
        }
        .alert("Export", isPresented: Binding(
            get: { exporter.summary != nil },
            set: { if !$0 { exporter.summary = nil } }
        )) {
            Button("OK") { exporter.summary = nil }
        } message: {
            Text(exporter.summary ?? "")
        }
        .alert("Artwork Fixer", isPresented: Binding(
            get: { artworkFixer.summary != nil },
            set: { if !$0 { artworkFixer.summary = nil } }
        )) {
            Button("OK") { artworkFixer.summary = nil }
        } message: {
            Text(artworkFixer.summary ?? "")
        }
        .overlay {
            if exporter.isRunning {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        ProgressView(value: Double(exporter.progress), total: Double(max(1, exporter.total)))
                            .frame(width: 220)
                        Text("Copying to Mac... (\(exporter.progress) / \(exporter.total))").bold()
                    }
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                }
                .ignoresSafeArea()
            } else if artworkFixer.isRunning {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        ProgressView(value: Double(artworkFixer.progress), total: Double(max(1, artworkFixer.total)))
                            .frame(width: 220)
                        Text("Fixing artwork... (\(artworkFixer.progress) / \(artworkFixer.total) albums)")
                            .bold()
                    }
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                }
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(spacing: 16) {
            // iPod icon
            Image(systemName: "ipod")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .gray],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("iPod")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            // Action buttons matching the OG app
            HStack(spacing: 8) {
                // Clean Up — delete selected or show confirm for all
                Button {
                    if selectedTracks.isEmpty {
                        showDeleteAllConfirm = true
                    } else {
                        showDeleteSelectedConfirm = true
                    }
                } label: {
                    Label("Clean Up", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                // Tools — artwork fixer, duplicate finder
                if mediaType == 1 {
                    Menu {
                        Button {
                            Task { await artworkFixer.fixAll(ipodManager: ipodManager) }
                        } label: {
                            Label("Fix All Missing Artwork", systemImage: "wand.and.stars")
                        }
                        Button {
                            showDuplicateFinder = true
                        } label: {
                            Label("Find Duplicates...", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button {
                            exportAllToMac()
                        } label: {
                            Label("Export All Music to Mac...", systemImage: "square.and.arrow.up.on.square")
                        }
                        Button {
                            showTrash = true
                        } label: {
                            Label("iPod Trash...", systemImage: "trash")
                        }
                    } label: {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                    .menuStyle(.borderedButton)
                    .frame(width: 100)
                }

                // Refresh — reload tracks from iPod database
                Button {
                    ipodManager.reloadTracks()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                
                // Eject
                Button {
                    ipodManager.eject()
                } label: {
                    Label("Eject", systemImage: "eject.fill")
                }
                .buttonStyle(.bordered)
            }
            
            // Search with scope
            Picker("", selection: $searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .frame(width: 84)
            TextField("Search iPod...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 4) {
            let trackCount = filteredTracks.count
            let typeName = mediaType == 2 ? (trackCount == 1 ? "movie" : "movies") :
                           (mediaType == 4 ? (trackCount == 1 ? "podcast" : "podcasts") :
                           (mediaType == 8 ? (trackCount == 1 ? "audiobook" : "audiobooks") :
                           (trackCount == 1 ? "song" : "songs")))
            
            Text("\(trackCount) \(typeName)")
                .fontWeight(.medium)
            
            if let ipod = deviceManager.connectedIPod {
                Text("·")
                    .foregroundColor(.secondary)
                Text("\(ipod.usedCapacityFormatted) of \(ipod.totalCapacityFormatted) used")
            }
            
            Spacer()
            
            if !selectedTracks.isEmpty {
                Text("\(selectedTracks.count) selected")
                    .foregroundColor(.accentColor)
                
                Button(role: .destructive) {
                    showDeleteSelectedConfirm = true
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Track Table
    
    private var trackTable: some View {
        Table(filteredTracks, selection: $selectedTracks, sortOrder: $sortOrder) {
            TableColumn("Title", value: \.displayTitle) { (track: TrackModel) in
                HStack(spacing: 8) {
                    trackArtworkThumb(for: track)
                    Text(track.displayTitle)
                        .fontWeight(.medium)
                }
            }
            .width(min: 170, ideal: 300)

            TableColumn("Artist", value: \.displayArtist) { (track: TrackModel) in
                Text(track.displayArtist)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Album", value: \.displayAlbum) { (track: TrackModel) in
                Text(track.displayAlbum)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Genre", value: \.displayGenre) { (track: TrackModel) in
                Text(track.displayGenre)
                    .foregroundColor(.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Year", value: \.yearValue) { (track: TrackModel) in
                Text(track.yearValue > 0 ? String(track.yearValue) : "—")
                    .foregroundColor(.secondary)
            }
            .width(min: 44, ideal: 54)

            TableColumn("Rating", value: \.rating) { (track: TrackModel) in
                Text(track.starRating > 0 ? String(repeating: "★", count: track.starRating) : "")
                    .foregroundColor(.yellow)
            }
            .width(min: 50, ideal: 70)

            TableColumn("Plays", value: \.playCount) { (track: TrackModel) in
                Text(track.playCount > 0 ? String(track.playCount) : "—")
                    .foregroundColor(.secondary)
            }
            .width(min: 40, ideal: 50)
        }
        .contextMenu(forSelectionType: TrackModel.ID.self) { selection in
            if selection.count == 1, let id = selection.first,
               let track = ipodManager.deviceTracks.first(where: { $0.id == id }) {
                // Single track context menu
                Button {
                    audioPlayer.play(track: track)
                } label: {
                    Label("Play", systemImage: "play.fill")
                }

                Button {
                    editingTracks = selection
                } label: {
                    Label("Edit Info...", systemImage: "pencil")
                }

                Button {
                    let mix = AutoMixEngine.geniusMix(seed: track, tracks: ipodManager.deviceTracks)
                    let count = AutoMixApplier.apply(mix, to: ipodManager)
                    print("[Genius] Created \(mix.name) with \(count) tracks")
                } label: {
                    Label("Genius Mix from This Song", systemImage: "wand.and.stars")
                }

                addToPlaylistMenu(selection: selection)

                Button {
                    exportToMac(selection: selection)
                } label: {
                    Label("Copy to Mac...", systemImage: "square.and.arrow.up")
                }

                Button {
                    NSWorkspace.shared.selectFile(track.filePath.path, inFileViewerRootedAtPath: track.filePath.deletingLastPathComponent().path)
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Divider()

                Button(role: .destructive) {
                    let idsToDelete = selection
                    selectedTracks.subtract(selection)
                    Task { @MainActor in
                        let _ = ipodManager.deleteTracks(ids: idsToDelete)
                    }
                } label: {
                    Label("Delete Track from iPod", systemImage: "trash")
                }
            } else if selection.count > 1 {
                // Multi-select context menu
                Button {
                    editingTracks = selection
                } label: {
                    Label("Edit \(selection.count) Tracks...", systemImage: "pencil")
                }

                addToPlaylistMenu(selection: selection)

                Button {
                    exportToMac(selection: selection)
                } label: {
                    Label("Copy \(selection.count) Tracks to Mac...", systemImage: "square.and.arrow.up")
                }

                Divider()

                Button {
                    showDeleteSelectedConfirm = true
                } label: {
                    Label("Delete \(selection.count) Tracks from iPod", systemImage: "trash")
                }
            }
        } primaryAction: { selection in
            // Double-click → play
            if let id = selection.first,
               let track = ipodManager.deviceTracks.first(where: { $0.id == id }) {
                audioPlayer.play(track: track)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: mediaType == 2 ? "film" : (mediaType == 4 ? "antenna.radiowaves.left.and.right" : (mediaType == 8 ? "book" : "music.note.list")))
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            let typeName = mediaType == 2 ? "Movies" : (mediaType == 4 ? "Podcasts" : (mediaType == 8 ? "Audiobooks" : "Songs"))
            Text("No \(typeName) on iPod")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Drag and drop files here to add them,\nor use the Sync button in the Overview tab.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var mediaType: UInt32 = 1 // 1=Audio, 2=Video, 4=Podcast, 8=Audiobook

    // MARK: - Artwork thumbnails

    @ViewBuilder
    private func trackArtworkThumb(for track: TrackModel) -> some View {
        if let image = artworkCache.artwork(for: track.displayAlbum, from: [track]) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if artworkCache.isMissing(track.displayAlbum) {
            // Definitively no artwork anywhere — make it easy to spot & fix
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange.opacity(0.15))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                )
                .help("No artwork — right-click → Edit Info → Find Artwork")
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                )
        }
    }

    // MARK: - Export to Mac

    private func exportToMac(selection: Set<TrackModel.ID>) {
        let tracks = ipodManager.deviceTracks.filter { selection.contains($0.id) }
        runExport(tracks: tracks)
    }

    private func exportAllToMac() {
        runExport(tracks: filteredTracks)
    }

    private func runExport(tracks: [TrackModel]) {
        guard !tracks.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to copy music into"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { _ = await exporter.export(tracks: tracks, to: url) }
    }

    // MARK: - Playlist menu

    @ViewBuilder
    private func addToPlaylistMenu(selection: Set<TrackModel.ID>) -> some View {
        let playlists = ipodManager.devicePlaylists.filter { !$0.isMaster && !$0.isPodcast }
        Menu {
            if playlists.isEmpty {
                Text("No playlists — create one in the Playlists tab")
            }
            ForEach(playlists) { pl in
                Button(pl.name) {
                    ipodManager.addTracksToPlaylist(trackUUIDs: selection, playlistId: pl.id)
                }
            }
        } label: {
            Label("Add to Playlist", systemImage: "text.badge.plus")
        }
    }

    // MARK: - Filtering

    private var filteredTracks: [TrackModel] {
        var tracks = ipodManager.deviceTracks.filter { track in
            if self.mediaType == 2 {
                return track.ipodMediaType == 2 || track.ipodMediaType == 32 || track.ipodMediaType == 64
            } else if self.mediaType == 4 {
                return track.ipodMediaType == 4
            } else if self.mediaType == 8 {
                return track.ipodMediaType == 8
            } else {
                return track.ipodMediaType == 1 || track.ipodMediaType == 0 || track.ipodMediaType == nil
            }
        }
        if !searchText.isEmpty {
            tracks = tracks.filter { track in
                switch searchScope {
                case .all:
                    return (track.title?.localizedCaseInsensitiveContains(searchText) == true) ||
                        (track.artist?.localizedCaseInsensitiveContains(searchText) == true) ||
                        (track.album?.localizedCaseInsensitiveContains(searchText) == true) ||
                        (track.genre?.localizedCaseInsensitiveContains(searchText) == true)
                case .title: return track.title?.localizedCaseInsensitiveContains(searchText) == true
                case .artist: return track.artist?.localizedCaseInsensitiveContains(searchText) == true
                case .album: return track.album?.localizedCaseInsensitiveContains(searchText) == true
                case .genre: return track.genre?.localizedCaseInsensitiveContains(searchText) == true
                }
            }
        }
        return tracks.sorted(using: sortOrder)
    }
}
