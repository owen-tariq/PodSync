import SwiftUI
import UniformTypeIdentifiers

/// Backup and restore playlists, smart playlists, and ratings to a JSON file,
/// so a wiped or replaced iPod can be rebuilt.
struct PlaylistBackupFile: Codable {
    struct TrackRef: Codable, Hashable {
        var title: String
        var artist: String
        var album: String
        var stars: Int
    }
    struct PlaylistEntry: Codable {
        var name: String
        var tracks: [TrackRef]
    }

    var exportedAt: Date
    var appVersion: String
    var deviceName: String
    var playlists: [PlaylistEntry]
    var smartPlaylists: [SmartPlaylist]
    var ratings: [TrackRef]
}

enum PlaylistBackup {

    nonisolated static func matchKey(title: String, artist: String, album: String) -> String {
        DuplicateFinder.normalize(title) + "|" + DuplicateFinder.normalize(artist) + "|" + DuplicateFinder.normalize(album)
    }

    nonisolated static func looseKey(title: String, artist: String) -> String {
        DuplicateFinder.normalize(title) + "|" + DuplicateFinder.normalize(artist)
    }

    /// Match backup track references against device tracks.
    /// Exact (title+artist+album) first, then loose (title+artist).
    nonisolated static func matchTracks(
        refs: [PlaylistBackupFile.TrackRef],
        tracks: [TrackModel]
    ) -> (matched: [(ref: PlaylistBackupFile.TrackRef, track: TrackModel)], missing: [PlaylistBackupFile.TrackRef]) {
        var exact: [String: TrackModel] = [:]
        var loose: [String: TrackModel] = [:]
        for t in tracks {
            exact[matchKey(title: t.displayTitle, artist: t.displayArtist, album: t.displayAlbum)] = t
            loose[looseKey(title: t.displayTitle, artist: t.displayArtist)] = t
        }

        var matched: [(PlaylistBackupFile.TrackRef, TrackModel)] = []
        var missing: [PlaylistBackupFile.TrackRef] = []
        for ref in refs {
            if let t = exact[matchKey(title: ref.title, artist: ref.artist, album: ref.album)] {
                matched.append((ref, t))
            } else if let t = loose[looseKey(title: ref.title, artist: ref.artist)] {
                matched.append((ref, t))
            } else {
                missing.append(ref)
            }
        }
        return (matched, missing)
    }

    // MARK: Create backup

    @MainActor
    static func makeBackup(ipodManager: IPodManager, deviceName: String) -> PlaylistBackupFile {
        func ref(_ t: TrackModel) -> PlaylistBackupFile.TrackRef {
            PlaylistBackupFile.TrackRef(
                title: t.displayTitle,
                artist: t.displayArtist,
                album: t.displayAlbum,
                stars: t.starRating
            )
        }

        let byIpodId = Dictionary(grouping: ipodManager.deviceTracks, by: { $0.ipodTrackId ?? 0 })

        let playlists: [PlaylistBackupFile.PlaylistEntry] = ipodManager.devicePlaylists
            .filter { !$0.isMaster && !$0.isPodcast }
            .map { pl in
                PlaylistBackupFile.PlaylistEntry(
                    name: pl.name,
                    tracks: pl.trackIds.compactMap { byIpodId[$0]?.first }.map(ref)
                )
            }

        let ratings = ipodManager.deviceTracks
            .filter { $0.starRating > 0 }
            .map(ref)

        return PlaylistBackupFile(
            exportedAt: Date(),
            appVersion: AppInfo.displayVersion,
            deviceName: deviceName,
            playlists: playlists,
            smartPlaylists: SmartPlaylistStore.shared.smartPlaylists,
            ratings: ratings
        )
    }

    // MARK: Restore

    @MainActor
    static func restore(_ file: PlaylistBackupFile, ipodManager: IPodManager) -> String {
        var restoredPlaylists = 0
        var totalMissing = 0

        for entry in file.playlists {
            let match = matchTracks(refs: entry.tracks, tracks: ipodManager.deviceTracks)
            totalMissing += match.missing.count

            if ipodManager.playlistNamed(entry.name) == nil {
                ipodManager.createPlaylist(name: entry.name)
            }
            guard let target = ipodManager.playlistNamed(entry.name) else { continue }
            let ids = match.matched.compactMap { $0.track.ipodTrackId }
            ipodManager.setPlaylistContents(playlistId: target.id, ipodTrackIds: ids)
            restoredPlaylists += 1
        }

        // Smart playlists back into the local store
        for sp in file.smartPlaylists {
            SmartPlaylistStore.shared.upsert(sp)
        }

        // Ratings
        var ratingsApplied = 0
        let ratingMatch = matchTracks(refs: file.ratings, tracks: ipodManager.deviceTracks)
        // Group by star value so we batch the DB writes
        let byStars = Dictionary(grouping: ratingMatch.matched, by: { $0.ref.stars })
        for (stars, pairs) in byStars where stars > 0 {
            var edit = IPodManager.TrackEdit()
            edit.rating = stars
            ipodManager.updateTracks(ipodIds: pairs.compactMap { $0.track.ipodTrackId }, edit: edit)
            ratingsApplied += pairs.count
        }

        var text = "Restored \(restoredPlaylists) playlists, \(file.smartPlaylists.count) smart playlists, \(ratingsApplied) ratings."
        if totalMissing > 0 {
            text += " \(totalMissing) tracks from the backup are not on this iPod."
        }
        return text
    }

    // MARK: File dialogs

    @MainActor
    static func backupViaPanel(ipodManager: IPodManager, deviceName: String) -> String? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PodSync Playlists \(Date().formatted(date: .numeric, time: .omitted)).json"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let backup = makeBackup(ipodManager: ipodManager, deviceName: deviceName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(backup).write(to: url)
            return "Backed up \(backup.playlists.count) playlists, \(backup.smartPlaylists.count) smart playlists, \(backup.ratings.count) ratings."
        } catch {
            return "Backup failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    static func restoreViaPanel(ipodManager: IPodManager) -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: url)
            let file = try decoder.decode(PlaylistBackupFile.self, from: data)
            return restore(file, ipodManager: ipodManager)
        } catch {
            return "Restore failed: \(error.localizedDescription)"
        }
    }
}
