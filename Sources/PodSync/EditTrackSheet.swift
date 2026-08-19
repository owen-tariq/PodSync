import SwiftUI

/// Edit metadata for one or more device tracks. Empty fields are left unchanged
/// (useful for batch editing: set only Album Artist across 40 tracks, etc).
struct EditTrackSheet: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss

    let trackIds: Set<UUID>

    @State private var title = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var albumArtist = ""
    @State private var genre = ""
    @State private var composer = ""
    @State private var yearText = ""
    @State private var trackNumText = ""
    @State private var discNumText = ""
    @State private var rating = 0
    @State private var artworkData: Data? = nil
    @State private var isFetchingArt = false
    @State private var isSaving = false
    @AppStorage(PodSyncSettings.artworkMaxSizeKey) private var artworkMaxSize: Int = 600

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    private var tracks: [TrackModel] {
        ipodManager.deviceTracks.filter { trackIds.contains($0.id) }
    }

    private var isBatch: Bool { trackIds.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isBatch ? "Edit \(trackIds.count) Tracks" : "Edit Track")
                    .font(.headline)
                Spacer()
            }
            .padding(12)

            Divider()

            HStack(alignment: .top, spacing: 16) {
                // Artwork panel
                VStack(spacing: 8) {
                    artworkPreview
                        .frame(width: 160, height: 160)
                        .cornerRadius(8)

                    Button {
                        fetchArtwork()
                    } label: {
                        if isFetchingArt {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Find Artwork", systemImage: "photo.badge.magnifyingglass")
                                .font(.caption)
                        }
                    }
                    .disabled(isFetchingArt)

                    Button {
                        chooseArtworkFile()
                    } label: {
                        Label("Choose File...", systemImage: "folder")
                            .font(.caption)
                    }

                    Picker("", selection: $artworkMaxSize) {
                        Text("300 px").tag(300)
                        Text("600 px").tag(600)
                        Text("1000 px").tag(1000)
                        Text("Original").tag(0)
                    }
                    .frame(width: 110)
                    Text("Saved size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Fields
                Form {
                    if !isBatch {
                        TextField("Title:", text: $title)
                    }
                    TextField("Artist:", text: $artist)
                    TextField("Album:", text: $album)
                    TextField("Album Artist:", text: $albumArtist)
                    TextField("Genre:", text: $genre)
                    TextField("Composer:", text: $composer)
                    HStack {
                        TextField("Year:", text: $yearText)
                            .frame(width: 120)
                        if !isBatch {
                            TextField("Track #:", text: $trackNumText)
                                .frame(width: 110)
                            TextField("Disc #:", text: $discNumText)
                                .frame(width: 100)
                        }
                    }
                    Picker("Rating:", selection: $rating) {
                        Text("No change").tag(-1)
                        ForEach(0...5, id: \.self) { stars in
                            Text(stars == 0 ? "None" : String(repeating: "★", count: stars)).tag(stars)
                        }
                    }

                    if isBatch {
                        Text("Only non-empty fields are applied to all \(trackIds.count) selected tracks.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save to iPod") { saveChanges() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving)
            }
            .padding(12)
        }
        .frame(width: 560)
        .onAppear { populate() }
    }

    @ViewBuilder
    private var artworkPreview: some View {
        if let data = artworkData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func populate() {
        rating = -1
        guard let first = tracks.first else { return }
        if !isBatch {
            title = first.title ?? ""
            artist = first.artist ?? ""
            album = first.album ?? ""
            albumArtist = first.albumArtist ?? ""
            genre = first.genre ?? ""
            yearText = first.year.map(String.init) ?? ""
            trackNumText = first.trackNumber.map(String.init) ?? ""
            discNumText = first.discNumber.map(String.init) ?? ""
            artworkData = first.artworkData

            // Device tracks don't carry artwork in memory — try the embedded
            // art in the file on the iPod so the current cover is visible.
            if artworkData == nil {
                let fileURL = first.filePath
                Task { @MainActor in
                    let data = await Task.detached(priority: .userInitiated) { () -> Data? in
                        let image = ArtworkCache.extractArtwork(from: fileURL)
                        return image?.tiffRepresentation.flatMap {
                            NSBitmapImageRep(data: $0)?.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                        }
                    }.value
                    if artworkData == nil, let data = data {
                        artworkData = data
                    }
                }
            }
        }
    }

    private func fetchArtwork() {
        let artistQuery = artist.isEmpty ? (tracks.first?.artist ?? "") : artist
        let albumQuery = album.isEmpty ? (tracks.first?.album ?? "") : album
        guard !artistQuery.isEmpty || !albumQuery.isEmpty else { return }
        isFetchingArt = true
        Task {
            if let data = await ArtworkFetcher.fetchArtwork(artist: artistQuery, album: albumQuery) {
                artworkData = data
            }
            isFetchingArt = false
        }
    }

    private func chooseArtworkFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            artworkData = try? Data(contentsOf: url)
        }
    }

    private func saveChanges() {
        isSaving = true

        var edit = IPodManager.TrackEdit()
        if !isBatch, !title.isEmpty { edit.title = title }
        if !artist.isEmpty { edit.artist = artist }
        if !album.isEmpty { edit.album = album }
        if !albumArtist.isEmpty { edit.albumArtist = albumArtist }
        if !genre.isEmpty { edit.genre = genre }
        if !composer.isEmpty { edit.composer = composer }
        if let year = Int(yearText) { edit.year = year }
        if !isBatch, let trackNum = Int(trackNumText) { edit.trackNumber = trackNum }
        if !isBatch, let discNum = Int(discNumText) { edit.discNumber = discNum }
        if rating >= 0 { edit.rating = rating }
        if let art = artworkData, art != tracks.first?.artworkData {
            let resized = ArtworkResizer.resizeToSetting(art)
            edit.artworkData = resized
            let albumName = !album.isEmpty ? album : tracks.first?.album
            ArtworkCache.shared.storeToDisk(data: resized, album: albumName)
        }

        ipodManager.updateTracks(ids: trackIds, edit: edit)
        isSaving = false
        dismiss()
    }
}
