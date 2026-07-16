import Foundation
import CLibGPod
import AppKit

/// Swift wrapper around the C-based libgpod library for iPod database management.
/// This provides a safe, Swift-friendly API for syncing tracks to classic iPods.
/// No licensing checks — free to use.
@MainActor
class IPodManager: ObservableObject {
    
    @Published var deviceTracks: [TrackModel] = []
    
    // Store as raw pointer since the C structs are opaque typedefs
    var dbRaw: OpaquePointer?
    private(set) var mountpoint: String?
    
    /// Parse an iPod database from a mounted iPod.
    @discardableResult
    func openIPod(at mountpoint: String) -> Bool {
        self.mountpoint = mountpoint
        
        print("[IPodManager] Attempting to parse database at \(mountpoint)...")
        
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
        
        guard rawDB != nil else {
            print("[IPodManager] Failed to parse or create iPod database at \(mountpoint)")
            return false
        }
        
        self.dbRaw = rawDB
        print("[IPodManager] Successfully opened iPod at \(mountpoint)")
        
        // Ensure SysInfo artwork formats and hashes are correctly setup to prevent corrupt art and skipping
        gpod_ensure_sysinfo_artwork_formats(rawDB)
        gpod_ensure_hash_info(rawDB)
        
        reloadTracks()
        
        // Extract Last.fm history
        if let rawDB = rawDB {
            Task {
                let currentPlaycounts = ScrobblerManager.shared.lastKnownPlaycounts
                let newScrobbles = ScrobblerManager.extractHistoryBackground(from: rawDB, currentPlaycounts: currentPlaycounts)
                
                if !newScrobbles.isEmpty {
                    print("[IPodManager] Found \(newScrobbles.count) new scrobbles.")
                    ScrobblerManager.shared.addPendingScrobbles(newScrobbles)
                }
            }
        }
        
        return true
    }
    
    /// Reload tracks from the iPod database into deviceTracks
    func reloadTracks() {
        guard let dbRaw = self.dbRaw, let mountpoint = self.mountpoint else { return }
        
        var count: UInt32 = 0
        guard let trackArray = gpod_get_all_tracks(dbRaw, &count) else {
            self.deviceTracks = []
            return
        }
        
        var newTracks: [TrackModel] = []
        
        for i in 0..<Int(count) {
            guard let trackPtr = trackArray[i] else { continue }
            let track = OpaquePointer(trackPtr)
            
            let id = gpod_track_get_id_field(track)
            
            let titlePtr = gpod_track_get_title_field(track)
            let title = titlePtr != nil ? String(cString: titlePtr!) : "Unknown Track"
            
            let artistPtr = gpod_track_get_artist_field(track)
            let artist = artistPtr != nil ? String(cString: artistPtr!) : "Unknown Artist"
            
            let albumPtr = gpod_track_get_album_field(track)
            let album = albumPtr != nil ? String(cString: albumPtr!) : "Unknown Album"
            
            // Reconstruct absolute path
            var absoluteURL: URL? = nil
            if let ipodPathPtr = gpod_track_get_ipod_path(track) {
                let ipodPathStr = String(cString: ipodPathPtr)
                // Convert ":iPod_Control:Music:Fxx:file.mp3" to "/iPod_Control/Music/Fxx/file.mp3"
                let normalizedPath = ipodPathStr.replacingOccurrences(of: ":", with: "/")
                absoluteURL = URL(fileURLWithPath: mountpoint).appendingPathComponent(normalizedPath)
            }
            
            var tm = TrackModel(
                id: UUID(),
                filePath: absoluteURL ?? URL(fileURLWithPath: "/dev/null"),
                title: title,
                artist: artist,
                album: album,
                albumArtist: nil,
                genre: nil,
                year: nil,
                trackNumber: nil,
                discNumber: nil,
                duration: 0,
                fileSize: 0,
                fileFormat: "MP3",
                dateAdded: Date(),
                artworkData: nil
            )
            tm.ipodTrackId = id
            newTracks.append(tm)
        }
        
        gpod_free_track_array(trackArray)
        
        self.deviceTracks = newTracks
    }
    
    /// Add a track to the iPod database and copy the file to the device.
    func addTrack(filePath: String, title: String, artist: String, album: String, artworkData: Data?, duration: TimeInterval, size: Int64, year: Int?, trackNum: Int?, discNum: Int?) -> Bool {
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
        title.withCString { cTitle in
            gpod_track_set_title(track, cTitle)
        }
        artist.withCString { cArtist in
            gpod_track_set_artist(track, cArtist)
        }
        album.withCString { cAlbum in
            gpod_track_set_album(track, cAlbum)
        }
        
        gpod_track_set_extended_info(
            track,
            Int32(duration * 1000),
            Int32(size),
            Int32(year ?? 0),
            Int32(trackNum ?? 0),
            Int32(discNum ?? 0)
        )
        
        // Add artwork if provided (MUST BE AFTER itdb_track_add so track->itdb is valid!)
        if let data = artworkData {
            let tempArtworkURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
            do {
                try data.write(to: tempArtworkURL)
                tempArtworkURL.path.withCString { cPath in
                    itdb_track_set_thumbnails(track, cPath)
                }
                try FileManager.default.removeItem(at: tempArtworkURL)
            } catch {
                print("[IPodManager] Failed to write temp artwork: \(error)")
            }
        }
        
        print("[IPodManager] Added track: \(title) by \(artist)")
        reloadTracks()
        return true
    }
    
    /// Delete a single track from the iPod database and filesystem
    func deleteTrack(id: UUID) -> Bool {
        guard let dbRaw = self.dbRaw else { return false }
        
        guard let trackModel = deviceTracks.first(where: { $0.id == id }),
              let ipodTrackId = trackModel.ipodTrackId else { return false }
              
        // Find the Itdb_Track pointer by ID
        var count: UInt32 = 0
        guard let trackArray = gpod_get_all_tracks(dbRaw, &count) else { return false }
        
        var foundTrackPtr: UnsafeMutableRawPointer? = nil
        for i in 0..<Int(count) {
            guard let ptr = trackArray[i] else { continue }
            if gpod_track_get_id_field(OpaquePointer(ptr)) == ipodTrackId {
                foundTrackPtr = ptr
                break
            }
        }
        gpod_free_track_array(trackArray)
        
        guard let trackPtr = foundTrackPtr else { return false }
        let track = OpaquePointer(trackPtr)
        
        // Explicitly remove from Master Playlist to prevent dangling pointers in libgpod
        if let mpl = itdb_playlist_mpl(dbRaw) {
            itdb_playlist_remove_track(mpl, track)
        }
        
        // Remove from database
        gpod_track_remove(dbRaw, track)
        
        // Delete from file system
        if FileManager.default.fileExists(atPath: trackModel.filePath.path) {
            do {
                try FileManager.default.removeItem(at: trackModel.filePath)
                print("[IPodManager] Deleted file: \(trackModel.filePath.path)")
            } catch {
                print("[IPodManager] Failed to delete file: \(error.localizedDescription)")
            }
        }
        
        return true
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
            print("[IPodManager] Database closed.")
        }
    }
}
