import SwiftUI

/// Shows all artists on the iPod grouped by artist name with artwork.
struct DeviceArtistsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @StateObject private var artworkCache = ArtworkCache.shared
    
    @State private var searchText = ""
    @State private var expandedArtist: String? = nil
    
    private var ipodManager: IPodManager {
        deviceManager.ipodManager
    }
    
    private var artistGroups: [(artist: String, trackCount: Int, tracks: [TrackModel])] {
        let tracks = ipodManager.deviceTracks
        var dict: [String: [TrackModel]] = [:]
        for track in tracks {
            let artist = track.artist ?? "Unknown Artist"
            dict[artist, default: []].append(track)
        }
        
        var result = dict.map { (artist: $0.key, trackCount: $0.value.count, tracks: $0.value) }
        result.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        
        if !searchText.isEmpty {
            result = result.filter { group in
                group.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "music.mic")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Artists on iPod")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(artistGroups.count) artists")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                TextField("Search Artists...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if artistGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Artists Found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(artistGroups, id: \.artist) { group in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedArtist == group.artist },
                                set: { expandedArtist = $0 ? group.artist : nil }
                            )
                        ) {
                            ForEach(group.tracks) { track in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title ?? "Unknown Title")
                                            .fontWeight(.medium)
                                        Text(track.album ?? "Unknown Album")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
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
                                artistArtView(for: group)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.artist)
                                        .fontWeight(.semibold)
                                    Text("\(group.trackCount) tracks")
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
    private func artistArtView(for group: (artist: String, trackCount: Int, tracks: [TrackModel])) -> some View {
        // Use the first track's album artwork as the artist image
        let firstAlbum = group.tracks.first?.album ?? group.artist
        if let nsImage = artworkCache.artwork(for: firstAlbum, from: group.tracks) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.6), .pink.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "music.mic")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                )
        }
    }
}
