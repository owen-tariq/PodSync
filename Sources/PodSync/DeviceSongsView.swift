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
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
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
                let _ = ipodManager.deleteTracks(ids: selectedTracks)
                selectedTracks.removeAll()
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
            let trackCount = ipodManager.deviceTracks.count
            
            Text("\(trackCount) tracks")
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
                    let _ = ipodManager.deleteTracks(ids: selection)
                    selectedTracks.subtract(selection)
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Songs on iPod")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Drag and drop music files here to add them,\nor use the Sync button in the Overview tab.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Filtering
    
    private var filteredTracks: [TrackModel] {
        let tracks = ipodManager.deviceTracks
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter { track in
            (track.title?.localizedCaseInsensitiveContains(searchText) == true) ||
            (track.artist?.localizedCaseInsensitiveContains(searchText) == true) ||
            (track.album?.localizedCaseInsensitiveContains(searchText) == true)
        }
    }
    
    // MARK: - Drag and Drop
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    guard let data = item as? Data,
                          let urlString = String(data: data, encoding: .utf8),
                          let url = URL(string: urlString) else { return }
                    
                    Task { @MainActor in
                        addFilesToIPod(url: url)
                    }
                }
            }
        }
        return true
    }
    
    @MainActor
    private func addFilesToIPod(url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            // It's a directory, enumerate its contents
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { return }
            for case let fileURL as URL in enumerator {
                if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegularFile {
                    if fileURL.pathExtension.lowercased() == "mp3" || fileURL.pathExtension.lowercased() == "m4a" {
                        addSingleFileToIPod(url: fileURL)
                    }
                }
            }
        } else {
            // It's a single file
            addSingleFileToIPod(url: url)
        }
        ipodManager.save()
    }
    
    @MainActor
    private func addSingleFileToIPod(url: URL) {
        let asset = AVAsset(url: url)
        
        let titleItem = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: .common).first
        let artistItem = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: .common).first
        let albumItem = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyAlbumName, keySpace: .common).first
        
        let title = titleItem?.stringValue ?? url.deletingPathExtension().lastPathComponent
        let artist = artistItem?.stringValue ?? "Unknown Artist"
        let album = albumItem?.stringValue ?? "Unknown Album"
        
        let success = ipodManager.addTrack(
            filePath: url.path,
            title: title,
            artist: artist,
            album: album,
            artworkData: nil,
            duration: CMTimeGetSeconds(asset.duration),
            size: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
            year: nil,
            trackNum: nil,
            discNum: nil
        )
        
        if success {
            print("Successfully added: \(title)")
        }
    }
}
