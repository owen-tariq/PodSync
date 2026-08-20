import Foundation
import CLibGPod
import AppKit

/// A playlist stored on the iPod.
struct PlaylistModel: Identifiable, Hashable, Sendable {
    let id: UInt64
    var name: String
    var trackIds: [UInt32]
    var isMaster: Bool
    var isPodcast: Bool

    var trackCount: Int { trackIds.count }
}

/// Extra metadata used when syncing podcast episodes to the device.
struct PodcastTrackMeta: Sendable {
    var episodeURL: String?
    var feedURL: String?
    var description: String?
    var subtitle: String?
    var releaseDate: Date?
    var markUnplayed: Bool = true
}

/// Swift wrapper around the C-based libgpod library for iPod database management.
/// This provides a safe, Swift-friendly API for syncing tracks to classic iPods.
/// No licensing checks — free to use.
@MainActor
class IPodManager: ObservableObject {

    @Published var deviceTracks: [TrackModel] = []
    @Published var devicePlaylists: [PlaylistModel] = []

    // Store as raw pointer since the C structs are opaque typedefs
    var dbRaw: OpaquePointer?
    private(set) var mountpoint: String?

    // MARK: - Track model building

    /// Build a TrackModel from a raw Itdb_Track pointer. Shared by open/reload paths.
    nonisolated static func buildTrackModel(from track: OpaquePointer, mountpoint: String) -> TrackModel {
        let id = gpod_track_get_id_field(track)

        func str(_ ptr: UnsafePointer<CChar>?) -> String? {
            guard let ptr = ptr else { return nil }
            let s = String(cString: ptr)
            return s.isEmpty ? nil : s
        }

        let title = str(gpod_track_get_title_field(track)) ?? "Unknown Track"
        let artist = str(gpod_track_get_artist_field(track)) ?? "Unknown Artist"
        let album = str(gpod_track_get_album_field(track)) ?? "Unknown Album"
        let genre = str(gpod_track_get_genre_field(track))
        let albumArtist = str(gpod_track_get_albumartist_field(track))
        let filetype = str(gpod_track_get_filetype_field(track))?.trimmingCharacters(in: .whitespaces)

        var absoluteURL: URL? = nil
        if let ipodPathPtr = gpod_track_get_ipod_path(track) {
            let ipodPathStr = String(cString: ipodPathPtr)
            let normalizedPath = ipodPathStr.replacingOccurrences(of: ":", with: "/")
            absoluteURL = URL(fileURLWithPath: mountpoint).appendingPathComponent(normalizedPath)
        }

        let year = Int(gpod_track_get_year(track))
        let trackNr = Int(gpod_track_get_track_nr(track))
        let discNr = Int(gpod_track_get_cd_nr(track))
        let durationMs = Int(gpod_track_get_tracklen(track))
        let size = Int64(gpod_track_get_size_field(track))
        let addedTime = gpod_track_get_time_added(track)
        let releasedTime = gpod_track_get_time_released(track)

        var tm = TrackModel(
            id: UUID(),
            filePath: absoluteURL ?? URL(fileURLWithPath: "/dev/null"),
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year > 0 ? year : nil,
            trackNumber: trackNr > 0 ? trackNr : nil,
            discNumber: discNr > 0 ? discNr : nil,
            duration: TimeInterval(durationMs) / 1000.0,
            fileSize: size,
            fileFormat: filetype ?? "MP3",
            dateAdded: addedTime > 0 ? Date(timeIntervalSince1970: TimeInterval(addedTime)) : Date(),
            artworkData: nil
        )
        tm.ipodTrackId = id
        tm.ipodMediaType = gpod_track_get_mediatype(track)
        tm.rating = Int(gpod_track_get_rating(track))
        tm.playCount = Int(gpod_track_get_playcount_field(track))
        tm.bitrate = Int(gpod_track_get_bitrate(track))
        tm.releaseDate = releasedTime > 0 ? Date(timeIntervalSince1970: TimeInterval(releasedTime)) : nil
        tm.podcastFeedURL = str(gpod_track_get_podcastrss_field(track))
        tm.isUnplayed = gpod_track_get_mark_unplayed(track) != 0
        return tm
    }

    nonisolated static func buildAllTracks(db: OpaquePointer, mountpoint: String) -> [TrackModel] {
        var newTracks: [TrackModel] = []
        var count: UInt32 = 0
        if let trackArray = gpod_get_all_tracks(db, &count) {
            for i in 0..<Int(count) {
                guard let trackPtr = trackArray[i] else { continue }
                newTracks.append(buildTrackModel(from: OpaquePointer(trackPtr), mountpoint: mountpoint))
            }
            gpod_free_track_array(trackArray)
        }
        return newTracks
    }

    nonisolated static func buildAllPlaylists(db: OpaquePointer) -> [PlaylistModel] {
        var result: [PlaylistModel] = []
        var count: UInt32 = 0
        guard let plArray = gpod_get_playlists(db, &count) else { return result }
        for i in 0..<Int(count) {
            guard let ptr = plArray[i] else { continue }
            let pl = OpaquePointer(ptr)
            let namePtr = gpod_playlist_get_name(pl)
            let name = namePtr != nil ? String(cString: namePtr!) : "Untitled"
            var trackIds: [UInt32] = []
            var tCount: UInt32 = 0
            if let tracks = gpod_playlist_get_tracks(pl, &tCount) {
                for j in 0..<Int(tCount) {
                    guard let tPtr = tracks[j] else { continue }
                    trackIds.append(gpod_track_get_id_field(OpaquePointer(tPtr)))
                }
                gpod_free_track_array(tracks)
            }
            result.append(PlaylistModel(
                id: gpod_playlist_get_id(pl),
                name: name,
                trackIds: trackIds,
                isMaster: gpod_playlist_is_master(pl) != 0,
                isPodcast: gpod_playlist_is_podcast_pl(pl) != 0
            ))
        }
        gpod_free_playlist_array(plArray)
        return result
    }

    // MARK: - Open / Reload

    /// Parse an iPod database from a mounted iPod on a background thread.
    func openIPod(at mountpoint: String) {
        self.mountpoint = mountpoint

        print("[IPodManager] Attempting to parse database at \(mountpoint) in background...")

        Task.detached(priority: .userInitiated) {
            var rawDB = mountpoint.withCString { cString in
                itdb_parse(cString, nil)
            }

            if rawDB == nil {
                print("[IPodManager] Database not found. Creating a new one.")
                rawDB = itdb_new()
                if let db = rawDB {
                    mountpoint.withCString { cString in
                        itdb_set_mountpoint(db, cString)
                    }
                    let mpl = "iPod".withCString { cTitle in
                        itdb_playlist_new(cTitle, 1)
                    }
                    itdb_playlist_set_mpl(mpl)
                    itdb_playlist_add(db, mpl, -1)
                }
            }

            guard let validDB = rawDB else {
                print("[IPodManager] Failed to parse or create iPod database at \(mountpoint)")
                return
            }

            print("[IPodManager] Successfully opened iPod at \(mountpoint)")

            // Ensure cryptographic hashes are correctly generated so the iPod Classic does not skip tracks
            gpod_ensure_hash_info(validDB)

            let newTracks = IPodManager.buildAllTracks(db: validDB, mountpoint: mountpoint)
            let newPlaylists = IPodManager.buildAllPlaylists(db: validDB)

            // Extract Last.fm history in background
            let currentPlaycounts = await ScrobblerManager.shared.lastKnownPlaycounts
            let newScrobbles = ScrobblerManager.extractHistoryBackground(from: validDB, currentPlaycounts: currentPlaycounts)

            // Commit to Main Actor
            await MainActor.run {
                self.dbRaw = validDB
                self.deviceTracks = newTracks
                self.devicePlaylists = newPlaylists

                if !newScrobbles.isEmpty {
                    print("[IPodManager] Found \(newScrobbles.count) new scrobbles.")
                    ScrobblerManager.shared.addPendingScrobbles(newScrobbles)
                }
            }
        }
    }

    /// Reload tracks and playlists from the iPod database
    func reloadTracks() {
        guard let dbRaw = self.dbRaw, let mountpoint = self.mountpoint else { return }
        self.deviceTracks = IPodManager.buildAllTracks(db: dbRaw, mountpoint: mountpoint)
        self.devicePlaylists = IPodManager.buildAllPlaylists(db: dbRaw)
    }

    /// Reload only playlists
    func reloadPlaylists() {
        guard let dbRaw = self.dbRaw else { return }
        self.devicePlaylists = IPodManager.buildAllPlaylists(db: dbRaw)
    }

    // MARK: - Adding tracks

    /// Add a track to the iPod database and copy the file to the device.
    @discardableResult
    func addTrack(
        filePath: String,
        title: String,
        artist: String,
        album: String,
        artworkData: Data?,
        duration: TimeInterval,
        size: Int64,
        year: Int?,
        trackNum: Int?,
        discNum: Int?,
        genre: String? = nil,
        albumArtist: String? = nil,
        composer: String? = nil,
        mediaTypeOverride: UInt32? = nil,
        podcastMeta: PodcastTrackMeta? = nil
    ) -> Bool {
        guard let dbRaw = self.dbRaw else {
            print("[IPodManager] No iPod database open.")
            return false
        }

        guard let track = itdb_track_new() else {
            print("[IPodManager] Failed to create new track.")
            return false
        }

        // Add track to the database (pass raw pointer directly)
        itdb_track_add(dbRaw, track, -1)

        // Add track to master playlist so it shows up in menus
        if let mpl = itdb_playlist_mpl(dbRaw) {
            itdb_playlist_add_track(mpl, track, -1)
        }

        // Copy the actual file to the iPod
        let musicDir = URL(fileURLWithPath: mountpoint!).appendingPathComponent("iPod_Control/Music")
        if !FileManager.default.fileExists(atPath: musicDir.path) {
            try? FileManager.default.createDirectory(at: musicDir, withIntermediateDirectories: true)
        }
        for i in 0..<50 {
            let fDir = musicDir.appendingPathComponent(String(format: "F%02d", i))
            if !FileManager.default.fileExists(atPath: fDir.path) {
                try? FileManager.default.createDirectory(at: fDir, withIntermediateDirectories: true)
            }
        }

        var error: UnsafeMutablePointer<GError>? = nil
        let success = filePath.withCString { cPath in
            itdb_cp_track_to_ipod(track, cPath, &error)
        }

        if success == 0 {
            print("[IPodManager] Failed to copy track to iPod.")
            if let err = error {
                print("[IPodManager] GError: \(String(cString: err.pointee.message))")
            }
            return false
        }

        // Set metadata AFTER copying so itdb_cp_track_to_ipod doesn't overwrite it
        title.withCString { gpod_track_set_title(track, $0) }
        artist.withCString { gpod_track_set_artist(track, $0) }
        album.withCString { gpod_track_set_album(track, $0) }
        if let genre = genre, !genre.isEmpty {
            genre.withCString { gpod_track_set_genre(track, $0) }
        }
        if let albumArtist = albumArtist, !albumArtist.isEmpty {
            albumArtist.withCString { gpod_track_set_albumartist(track, $0) }
        }
        if let composer = composer, !composer.isEmpty {
            composer.withCString { gpod_track_set_composer(track, $0) }
        }

        let ext = URL(fileURLWithPath: filePath).pathExtension.lowercased()

        let filetypeStr: String
        if ["mp4", "m4v", "mov"].contains(ext) {
            filetypeStr = "mp4 "
        } else if ext == "mp3" {
            filetypeStr = "mp3 "
        } else {
            filetypeStr = "m4a "
        }
        filetypeStr.withCString { cFiletype in
            gpod_track_set_filetype(track, cFiletype)
        }

        // 1=Audio, 2=Video, 4=Podcast, 8=Audiobook
        let mediaType: UInt32
        if let override = mediaTypeOverride {
            mediaType = override
        } else if ["mp4", "m4v", "mov"].contains(ext) {
            mediaType = 2
        } else if ext == "m4b" {
            mediaType = 8
        } else if ext == "m4p" {
            mediaType = 4
        } else {
            mediaType = 1
        }
        gpod_track_set_mediatype(track, mediaType)

        gpod_track_set_extended_info(
            track,
            Int32(duration * 1000),
            Int32(size),
            Int32(year ?? 0),
            Int32(trackNum ?? 0),
            Int32(discNum ?? 0)
        )

        // Podcast-specific metadata + membership in the Podcasts playlist
        if let meta = podcastMeta, mediaType == 4 {
            let released = meta.releaseDate.map { time_t($0.timeIntervalSince1970) } ?? 0
            withCStringOrNull(meta.episodeURL) { cURL in
                withCStringOrNull(meta.feedURL) { cRSS in
                    withCStringOrNull(meta.description) { cDesc in
                        withCStringOrNull(meta.subtitle) { cSub in
                            gpod_track_set_podcast_meta(track, cURL, cRSS, cDesc, cSub, released, meta.markUnplayed ? 1 : 0)
                        }
                    }
                }
            }
            let podcastsPl = ensurePodcastsPlaylist()
            if let pl = podcastsPl {
                itdb_playlist_add_track(pl, track, -1)
            }
        }

        // Add artwork if provided (MUST BE AFTER itdb_track_add so track->itdb is valid!)
        if let data = artworkData {
            data.withUnsafeBytes { rawBufferPointer in
                if let baseAddress = rawBufferPointer.baseAddress {
                    gpod_track_set_artwork_from_data(track, baseAddress, data.count)
                }
            }
        }

        print("[IPodManager] Added track: \(title) by \(artist)")
        reloadTracks()
        return true
    }

    private func withCStringOrNull<R>(_ string: String?, _ body: (UnsafePointer<CChar>?) -> R) -> R {
        if let string = string {
            return string.withCString { body($0) }
        }
        return body(nil)
    }

    // MARK: - Metadata editing

    /// Fields that can be edited on a device track. Nil = leave unchanged.
    struct TrackEdit {
        var title: String? = nil
        var artist: String? = nil
        var album: String? = nil
        var albumArtist: String? = nil
        var genre: String? = nil
        var composer: String? = nil
        var year: Int? = nil
        var trackNumber: Int? = nil
        var discNumber: Int? = nil
        var rating: Int? = nil // 0-5 stars
        var artworkData: Data? = nil
    }

    /// Apply metadata edits to one or more device tracks. Saves the database once.
    @discardableResult
    func updateTracks(ids: Set<UUID>, edit: TrackEdit) -> Bool {
        guard let dbRaw = self.dbRaw else { return false }
        var changed = false

        for uuid in ids {
            guard let model = deviceTracks.first(where: { $0.id == uuid }),
                  let ipodId = model.ipodTrackId,
                  let track = itdb_track_by_id(dbRaw, ipodId) else { continue }

            if let v = edit.title, !v.isEmpty { v.withCString { gpod_track_set_title(track, $0) }; changed = true }
            if let v = edit.artist, !v.isEmpty { v.withCString { gpod_track_set_artist(track, $0) }; changed = true }
            if let v = edit.album, !v.isEmpty { v.withCString { gpod_track_set_album(track, $0) }; changed = true }
            if let v = edit.albumArtist, !v.isEmpty { v.withCString { gpod_track_set_albumartist(track, $0) }; changed = true }
            if let v = edit.genre { v.withCString { gpod_track_set_genre(track, $0) }; changed = true }
            if let v = edit.composer, !v.isEmpty { v.withCString { gpod_track_set_composer(track, $0) }; changed = true }
            if let v = edit.year { gpod_track_set_year(track, Int32(v)); changed = true }
            if let v = edit.trackNumber { gpod_track_set_track_nr(track, Int32(v)); changed = true }
            if let v = edit.discNumber { gpod_track_set_cd_nr(track, Int32(v)); changed = true }
            if let v = edit.rating { gpod_track_set_rating(track, UInt32(min(5, max(0, v)) * 20)); changed = true }
            if let data = edit.artworkData {
                data.withUnsafeBytes { buf in
                    if let base = buf.baseAddress {
                        gpod_track_set_artwork_from_data(track, base, data.count)
                    }
                }
                changed = true
            }
        }

        if changed {
            save()
            reloadTracks()
        }
        return changed
    }

    /// Apply edits addressed by stable iPod track ids (safe across reloads,
    /// unlike UUIDs which are regenerated on every reload).
    @discardableResult
    func updateTracks(ipodIds: [UInt32], edit: TrackEdit) -> Bool {
        let idSet = Set(ipodIds)
        let uuids = Set(deviceTracks.filter { t in t.ipodTrackId.map(idSet.contains) ?? false }.map(\.id))
        guard !uuids.isEmpty else { return false }
        return updateTracks(ids: uuids, edit: edit)
    }

    // MARK: - Playlists

    /// Find the raw playlist pointer for a PlaylistModel id.
    private func rawPlaylist(id: UInt64) -> OpaquePointer? {
        guard let dbRaw = self.dbRaw else { return nil }
        return itdb_playlist_by_id(dbRaw, id)
    }

    /// Get or create the special Podcasts playlist.
    func ensurePodcastsPlaylist() -> OpaquePointer? {
        guard let dbRaw = self.dbRaw else { return nil }
        if let existing = itdb_playlist_podcasts(dbRaw) {
            return existing
        }
        let pl = "Podcasts".withCString { itdb_playlist_new($0, 0) }
        guard let newPl = pl else { return nil }
        itdb_playlist_set_podcasts(newPl)
        itdb_playlist_add(dbRaw, newPl, -1)
        return newPl
    }

    /// Create a new standard playlist. Returns true on success.
    @discardableResult
    func createPlaylist(name: String) -> Bool {
        guard let dbRaw = self.dbRaw, !name.isEmpty else { return false }
        let pl = name.withCString { itdb_playlist_new($0, 0) }
        guard let newPl = pl else { return false }
        itdb_playlist_add(dbRaw, newPl, -1)
        save()
        reloadPlaylists()
        return true
    }

    @discardableResult
    func renamePlaylist(id: UInt64, newName: String) -> Bool {
        guard let pl = rawPlaylist(id: id), !newName.isEmpty else { return false }
        newName.withCString { gpod_playlist_set_name(pl, $0) }
        save()
        reloadPlaylists()
        return true
    }

    /// Delete a playlist (tracks stay on the device).
    @discardableResult
    func deletePlaylist(id: UInt64) -> Bool {
        guard let pl = rawPlaylist(id: id) else { return false }
        if gpod_playlist_is_master(pl) != 0 { return false }
        itdb_playlist_remove(pl)
        save()
        reloadPlaylists()
        return true
    }

    /// Add device tracks (by UUID) to a playlist.
    @discardableResult
    func addTracksToPlaylist(trackUUIDs: Set<UUID>, playlistId: UInt64) -> Bool {
        guard let dbRaw = self.dbRaw, let pl = rawPlaylist(id: playlistId) else { return false }
        var added = false
        for uuid in trackUUIDs {
            guard let model = deviceTracks.first(where: { $0.id == uuid }),
                  let ipodId = model.ipodTrackId,
                  let track = itdb_track_by_id(dbRaw, ipodId) else { continue }
            if itdb_playlist_contains_track(pl, track) == 0 {
                itdb_playlist_add_track(pl, track, -1)
                added = true
            }
        }
        if added {
            save()
            reloadPlaylists()
        }
        return added
    }

    /// Remove device tracks (by iPod track id) from a playlist.
    @discardableResult
    func removeTracksFromPlaylist(ipodTrackIds: [UInt32], playlistId: UInt64) -> Bool {
        guard let dbRaw = self.dbRaw, let pl = rawPlaylist(id: playlistId) else { return false }
        var removed = false
        for tid in ipodTrackIds {
            guard let track = itdb_track_by_id(dbRaw, tid) else { continue }
            if itdb_playlist_contains_track(pl, track) != 0 {
                itdb_playlist_remove_track(pl, track)
                removed = true
            }
        }
        if removed {
            save()
            reloadPlaylists()
        }
        return removed
    }

    /// Replace the entire contents of a playlist with the given device tracks (used by Smart Playlists).
    @discardableResult
    func setPlaylistContents(playlistId: UInt64, ipodTrackIds: [UInt32]) -> Bool {
        guard let dbRaw = self.dbRaw, let pl = rawPlaylist(id: playlistId) else { return false }

        // Remove all current members
        var count: UInt32 = 0
        if let tracks = gpod_playlist_get_tracks(pl, &count) {
            for i in 0..<Int(count) {
                guard let tPtr = tracks[i] else { continue }
                itdb_playlist_remove_track(pl, OpaquePointer(tPtr))
            }
            gpod_free_track_array(tracks)
        }

        // Add new members in order
        for tid in ipodTrackIds {
            guard let track = itdb_track_by_id(dbRaw, tid) else { continue }
            itdb_playlist_add_track(pl, track, -1)
        }
        save()
        reloadPlaylists()
        return true
    }

    /// Find an existing playlist by name (excluding master).
    func playlistNamed(_ name: String) -> PlaylistModel? {
        devicePlaylists.first { !$0.isMaster && $0.name == name }
    }

    // MARK: - Deleting tracks

    /// Delete a single track from the iPod database and filesystem
    func deleteTrack(id: UUID) -> Bool {
        guard let dbRaw = self.dbRaw else { return false }

        guard let trackModel = deviceTracks.first(where: { $0.id == id }),
              let ipodTrackId = trackModel.ipodTrackId,
              let track = itdb_track_by_id(dbRaw, ipodTrackId) else { return false }

        // Remove from ALL playlists to prevent dangling pointers in libgpod
        var plCount: UInt32 = 0
        if let plArray = gpod_get_playlists(dbRaw, &plCount) {
            for i in 0..<Int(plCount) {
                guard let plPtr = plArray[i] else { continue }
                let pl = OpaquePointer(plPtr)
                if itdb_playlist_contains_track(pl, track) != 0 {
                    itdb_playlist_remove_track(pl, track)
                }
            }
            gpod_free_playlist_array(plArray)
        }

        // Remove from database
        gpod_track_remove(dbRaw, track)

        // Move the file to the on-device trash instead of deleting it outright,
        // so accidental deletions are recoverable until the trash is emptied.
        if FileManager.default.fileExists(atPath: trackModel.filePath.path) {
            do {
                if let trashDir = trashDirectory {
                    try? FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
                    let safeName = "\(trackModel.displayArtist) - \(trackModel.displayTitle)"
                        .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "_")
                    var dest = trashDir.appendingPathComponent(safeName).appendingPathExtension(trackModel.filePath.pathExtension)
                    var counter = 2
                    while FileManager.default.fileExists(atPath: dest.path) {
                        dest = trashDir.appendingPathComponent("\(safeName) \(counter)").appendingPathExtension(trackModel.filePath.pathExtension)
                        counter += 1
                    }
                    try FileManager.default.moveItem(at: trackModel.filePath, to: dest)
                    print("[IPodManager] Moved to trash: \(dest.lastPathComponent)")
                } else {
                    try FileManager.default.removeItem(at: trackModel.filePath)
                }
            } catch {
                print("[IPodManager] Failed to trash file: \(error.localizedDescription)")
            }
        }

        return true
    }

    // MARK: - iPod Trash

    /// On-device trash folder — deleted tracks live here until emptied.
    var trashDirectory: URL? {
        mountpoint.map { URL(fileURLWithPath: $0).appendingPathComponent("iPod_Control/PodSync_Trash", isDirectory: true) }
    }

    struct TrashItem: Identifiable, Hashable {
        var id: URL { url }
        let url: URL
        let name: String
        let size: Int64
        let date: Date
    }

    func trashItems() -> [TrashItem] {
        guard let dir = trashDirectory,
              let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return [] }
        return contents.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return TrashItem(
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                size: Int64(values?.fileSize ?? 0),
                date: values?.contentModificationDate ?? Date()
            )
        }.sorted { $0.date > $1.date }
    }

    /// Permanently delete everything in the trash. Returns freed bytes.
    @discardableResult
    func emptyTrash() -> Int64 {
        let items = trashItems()
        var freed: Int64 = 0
        for item in items {
            if (try? FileManager.default.removeItem(at: item.url)) != nil {
                freed += item.size
            }
        }
        return freed
    }

    /// Delete multiple tracks and save once at the end
    func deleteTracks(ids: Set<UUID>) -> Bool {
        var anyDeleted = false
        for id in ids {
            if deleteTrack(id: id) {
                anyDeleted = true
            }
        }
        if anyDeleted {
            let saved = save()
            reloadTracks()
            return saved
        }
        return false
    }

    /// Delete ALL tracks from the iPod
    func deleteAllTracks() -> Bool {
        let allIds = Set(deviceTracks.map { $0.id })
        return deleteTracks(ids: allIds)
    }

    // MARK: - Persistence & lifecycle

    /// Write the database back to the iPod.
    @discardableResult
    func save() -> Bool {
        guard let dbRaw = self.dbRaw else { return false }

        let result = itdb_write(dbRaw, nil)

        if result == 0 {
            print("[IPodManager] Failed to write database")
            return false
        }

        print("[IPodManager] Database saved successfully.")
        return true
    }

    /// Eject the iPod volume
    func eject() {
        guard let mountpoint = self.mountpoint else { return }
        close()

        let url = URL(fileURLWithPath: mountpoint)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            print("[IPodManager] iPod ejected successfully.")
        } catch {
            print("[IPodManager] Failed to eject iPod: \(error.localizedDescription)")
        }
    }

    /// Close the database and free memory.
    func close() {
        if let dbRaw = self.dbRaw {
            itdb_free(dbRaw)
            self.dbRaw = nil
            self.mountpoint = nil
            self.deviceTracks = []
            self.devicePlaylists = []
            print("[IPodManager] Database closed.")
        }
    }
}
