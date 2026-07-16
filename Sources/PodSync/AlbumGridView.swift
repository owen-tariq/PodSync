import SwiftUI

struct AlbumGridView: View {
    @EnvironmentObject var libraryManager: LibraryManager

    private var albums: [AlbumGroup] {
        let grouped = Dictionary(grouping: libraryManager.tracks) { track in
            track.album ?? "Unknown Album"
        }
        return grouped.map { key, tracks in
            AlbumGroup(
                name: key,
                artist: tracks.first?.artist ?? "Unknown Artist",
                artworkData: tracks.first(where: { $0.artworkData != nil })?.artworkData,
                trackCount: tracks.count
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if albums.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(albums) { album in
                            albumCard(album)
                        }
                    }
                    .padding(24)
                }

                // Footer
                HStack {
                    Text("\(albums.count) albums")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Album Card

    @ViewBuilder
    private func albumCard(_ album: AlbumGroup) -> some View {
        Button {
            print("Selected album: \(album.name)")
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Artwork
                albumArtwork(album)
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Text(album.artist)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Album Artwork

    @ViewBuilder
    private func albumArtwork(_ album: AlbumGroup) -> some View {
        if let artworkData = album.artworkData,
           let nsImage = NSImage(data: artworkData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: albumGradient(for: album.name),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "music.note")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Albums")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add music to your library to see albums here.")
                .foregroundColor(.secondary)
            Button("Add Music Folder") {
                libraryManager.addLibraryFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    /// Generates a deterministic gradient based on album name for visual variety.
    private func albumGradient(for name: String) -> [Color] {
        let hash = abs(name.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.4, brightness: 0.35),
            Color(hue: hue2, saturation: 0.3, brightness: 0.25)
        ]
    }
}

// MARK: - Album Group Model

struct AlbumGroup: Identifiable {
    let id = UUID()
    let name: String
    let artist: String
    let artworkData: Data?
    let trackCount: Int
}
