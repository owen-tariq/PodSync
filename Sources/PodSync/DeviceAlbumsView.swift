import SwiftUI

/// Shows all albums on the iPod grouped by album name with artwork.
struct DeviceAlbumsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @StateObject private var artworkCache = ArtworkCache.shared
    
    @State private var searchText = ""
    @State private var expandedAlbum: String? = nil
    
    private var ipodManager: IPodManager {
        deviceManager.ipodManager
    }
    
    private var albumGroups: [(album: String, artist: String, tracks: [TrackModel])] {
        let tracks = ipodManager.deviceTracks
        var dict: [String: [TrackModel]] = [:]
        for track in tracks {
            let album = track.album ?? "Unknown Album"
            dict[album, default: []].append(track)
        }
        
        var result = dict.map { (album: $0.key, artist: $0.value.first?.artist ?? "Unknown Artist", tracks: $0.value) }
        result.sort { $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending }
        
        if !searchText.isEmpty {
            result = result.filter { group in
                group.album.localizedCaseInsensitiveContains(searchText) ||
                group.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.stack")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Albums on iPod")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(albumGroups.count) albums")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                TextField("Search Albums...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if albumGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Albums Found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(albumGroups, id: \.album) { group in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedAlbum == group.album },
                                set: { expandedAlbum = $0 ? group.album : nil }
                            )
                        ) {
                            ForEach(group.tracks) { track in
                                HStack {
                                    Text(track.title ?? "Unknown Title")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(track.durationFormatted)
                                        .foregroundColor(.secondary)
                                        .fontDesign(.monospaced)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    audioPlayer.play(track: track)
                                }
                                .contextMenu {
                                    Button {
                                        audioPlayer.play(track: track)
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        let _ = ipodManager.deleteTracks(ids: [track.id])
                                    } label: {
                                        Label("Delete from iPod", systemImage: "trash")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                albumArtView(for: group)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.album)
                                        .fontWeight(.semibold)
                                    Text("\(group.artist) · \(group.tracks.count) tracks")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func albumArtView(for group: (album: String, artist: String, tracks: [TrackModel])) -> some View {
        if let nsImage = artworkCache.artwork(for: group.album, from: group.tracks) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.white)
                )
        }
    }
}
