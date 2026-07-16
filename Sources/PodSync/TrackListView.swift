import SwiftUI
import UniformTypeIdentifiers

struct TrackListView: View {
    @EnvironmentObject var libraryManager: LibraryManager

    @Binding var searchText: String
    @Binding var selectedTracks: Set<TrackModel.ID>

    @State private var sortOrder: [KeyPathComparator<TrackModel>] = [
        KeyPathComparator(\TrackModel.title, order: .forward)
    ]

    private var filteredTracks: [TrackModel] {
        let tracks: [TrackModel]
        if searchText.isEmpty {
            tracks = libraryManager.tracks
        } else {
            let query = searchText.lowercased()
            tracks = libraryManager.tracks.filter { track in
                (track.title?.lowercased().contains(query) ?? false) ||
                (track.artist?.lowercased().contains(query) ?? false) ||
                (track.album?.lowercased().contains(query) ?? false) ||
                (track.genre?.lowercased().contains(query) ?? false)
            }
        }
        return tracks.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            if libraryManager.tracks.isEmpty && !libraryManager.isScanning {
                emptyState
            } else {
                trackTable

                // Footer
                HStack {
                    if libraryManager.isScanning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(filteredTracks.count) tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !searchText.isEmpty && filteredTracks.count != libraryManager.tracks.count {
                            Text("(filtered from \(libraryManager.tracks.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    
                    Button {
                        libraryManager.addLibraryFolder()
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        Task { @MainActor in
                            libraryManager.addFilesOrFolders(urls: [url])
                        }
                    }
                }
            }
            return true
        }
    }

    // MARK: - Track Table

    @ViewBuilder
    private var trackTable: some View {
        Table(filteredTracks, selection: $selectedTracks, sortOrder: $sortOrder) {
            TableColumn("Title", value: \.fileFormat) { track in
                Text(track.title ?? track.filePath.deletingPathExtension().lastPathComponent)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 220)

            TableColumn("Artist", value: \.fileFormat) { track in
                Text(track.artist ?? "Unknown Artist")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Album", value: \.fileFormat) { track in
                Text(track.album ?? "Unknown Album")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Duration") { (track: TrackModel) in
                Text(track.durationFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 50, ideal: 65, max: 80)

            TableColumn("Format") { (track: TrackModel) in
                Text(track.fileFormat.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 50, ideal: 65, max: 80)
        }
        .contextMenu(forSelectionType: TrackModel.ID.self) { ids in
            if !ids.isEmpty {
                Button("Show in Finder") {
                    showInFinder(trackIDs: ids)
                }
            }
        } primaryAction: { ids in
            // Double-click to play (future implementation)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Get Started")
                .font(.title2)
                .fontWeight(.bold)
            Text("Add your music library to begin managing your iPod.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Add Music Folder") {
                libraryManager.addLibraryFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func showInFinder(trackIDs: Set<TrackModel.ID>) {
        let urls = libraryManager.tracks
            .filter { trackIDs.contains($0.id) }
            .map { $0.filePath }
        if !urls.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }
}
