import Foundation

/// Batch-fixes missing artwork across the whole device: finds albums with no
/// artwork anywhere (memory cache, disk cache, embedded in file), looks up
/// covers via the iTunes Search API, and writes them to the iPod.
@MainActor
final class ArtworkFixer: ObservableObject {
    static let shared = ArtworkFixer()

    @Published private(set) var isRunning = false
    @Published private(set) var progress = 0
    @Published private(set) var total = 0
    @Published var summary: String? = nil

    private init() {}

    func fixAll(ipodManager: IPodManager) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // Music tracks only, grouped by album; carry stable iPod ids
        let music = ipodManager.deviceTracks.filter {
            let mt = $0.ipodMediaType ?? 1
            return mt == 1 || mt == 0
        }
        let groups = Dictionary(grouping: music, by: { $0.displayAlbum })

        // Find albums with no artwork anywhere
        var missing: [(album: String, artist: String, ipodIds: [UInt32])] = []
        for (album, tracks) in groups {
            if ArtworkCache.shared.cache[album] != nil { continue }
            let fileURL = tracks.first(where: { FileManager.default.fileExists(atPath: $0.filePath.path) })?.filePath
            let albumName = album
            let hasArt = await Task.detached(priority: .userInitiated) { () -> Bool in
                if ArtworkCache.hasDiskArtwork(album: albumName) { return true }
                if let fileURL = fileURL, ArtworkCache.extractArtwork(from: fileURL) != nil { return true }
                return false
            }.value
            if !hasArt {
                missing.append((
                    album: album,
                    artist: tracks.first?.displayArtist ?? "",
                    ipodIds: tracks.compactMap(\.ipodTrackId)
                ))
            }
        }

        total = missing.count
        progress = 0

        guard !missing.isEmpty else {
            summary = "All albums already have artwork. Nothing to fix."
            return
        }

        var fixed = 0
        var failed: [String] = []

        for item in missing {
            if let data = await ArtworkFetcher.fetchArtwork(artist: item.artist, album: item.album) {
                let resized = ArtworkResizer.resizeToSetting(data)
                ArtworkCache.shared.storeToDisk(data: resized, album: item.album)
                var edit = IPodManager.TrackEdit()
                edit.artworkData = resized
                ipodManager.updateTracks(ipodIds: item.ipodIds, edit: edit)
                fixed += 1
            } else {
                failed.append(item.album)
            }
            progress += 1
        }

        var text = "Fixed artwork for \(fixed) of \(missing.count) albums."
        if !failed.isEmpty {
            text += " Not found: \(failed.prefix(5).joined(separator: ", "))" + (failed.count > 5 ? "…" : "")
        }
        summary = text
    }
}
