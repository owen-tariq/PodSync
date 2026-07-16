import SwiftUI
import AppKit
import AVFoundation

/// The main iPod songs management view — matching the OG app's layout.
/// Shows all tracks on the iPod with Clean Up / Refresh / Eject toolbar,
/// stats bar, multi-select, right-click context menu, drag-and-drop add.
struct DeviceSongsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    @State private var selectedTracks = Set<TrackModel.ID>()
    @State private var searchText = ""
    @State private var showDeleteAllConfirm = false
    @State private var showDeleteSelectedConfirm = false
    
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
            
            // Search
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
        Table(filteredTracks, selection: $selectedTracks) {
            TableColumn("Title") { (track: TrackModel) in
                Text(track.title ?? "Unknown Title")
                    .fontWeight(.medium)
            }
            .width(min: 150, ideal: 300)
            
            TableColumn("Artist") { (track: TrackModel) in
                Text(track.artist ?? "Unknown Artist")
            }
            .width(min: 100, ideal: 200)
            
            TableColumn("Album") { (track: TrackModel) in
                Text(track.album ?? "Unknown Album")
            }
            .width(min: 100, ideal: 200)
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
    
    // MARK: - Filtering
    
    private var filteredTracks: [TrackModel] {
        let tracks = ipodManager.deviceTracks.filter { track in
            if self.mediaType == 2 {
                return track.ipodMediaType == 2 || track.ipodMediaType == 32 || track.ipodMediaType == 64
            } else if self.mediaType == 4 {
                return track.ipodMediaType == 4
            } else if self.mediaType == 8 {
                return track.ipodMediaType == 8
            } else {
                return track.ipodMediaType == 1 || track.ipodMediaType == 0
            }
        }
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter { track in
            (track.title?.localizedCaseInsensitiveContains(searchText) == true) ||
            (track.artist?.localizedCaseInsensitiveContains(searchText) == true) ||
            (track.album?.localizedCaseInsensitiveContains(searchText) == true)
        }
    }
}
