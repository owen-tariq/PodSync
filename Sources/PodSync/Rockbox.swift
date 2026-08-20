import Foundation

/// Support for iPods running the Rockbox open-source firmware.
/// Rockbox reads plain files from the filesystem (no iTunesDB), and logs
/// listening history to a `.scrobbler.log` file at the volume root.
enum Rockbox {

    /// Whether the mounted volume has Rockbox installed (`.rockbox` folder).
    nonisolated static func isInstalled(mountpoint: String) -> Bool {
        var isDir: ObjCBool = false
        let path = URL(fileURLWithPath: mountpoint).appendingPathComponent(".rockbox").path
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// One played entry from a Rockbox scrobbler log.
    struct LogEntry: Equatable {
        var artist: String
        var album: String
        var title: String
        var timestamp: Date
    }

    /// Parse a Rockbox `.scrobbler.log` (Audioscrobbler portable log v1.1).
    /// Tab-separated: artist, album, title, trackNumber, length, rating (L=listened / S=skipped), timestamp[, mbid].
    /// Only "L" (listened) lines are returned.
    nonisolated static func parseScrobblerLog(_ text: String) -> [LogEntry] {
        var entries: [LogEntry] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let fields = line.components(separatedBy: "\t")
            guard fields.count >= 7 else { continue }
            let rating = fields[5].uppercased()
            guard rating == "L" else { continue }
            guard let ts = TimeInterval(fields[6]), ts > 0 else { continue }
            entries.append(LogEntry(
                artist: fields[0],
                album: fields[1],
                title: fields[2],
                timestamp: Date(timeIntervalSince1970: ts)
            ))
        }
        return entries
    }

    /// Path of the scrobbler log on a mounted Rockbox iPod (nil if absent).
    nonisolated static func scrobblerLogURL(mountpoint: String) -> URL? {
        let url = URL(fileURLWithPath: mountpoint).appendingPathComponent(".scrobbler.log")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Import the device's scrobbler log into the pending-scrobbles queue.
    /// The log file is renamed to `.scrobbler.log.imported` so entries aren't
    /// double-counted next time. Returns the number of listens imported.
    @MainActor
    static func importScrobbles(mountpoint: String, into manager: ScrobblerManager) -> Int {
        guard let logURL = scrobblerLogURL(mountpoint: mountpoint),
              let text = try? String(contentsOf: logURL, encoding: .utf8) else { return 0 }

        let entries = parseScrobblerLog(text)
        guard !entries.isEmpty else { return 0 }

        let pending = entries.map { entry in
            PendingScrobble(
                trackId: 0,
                title: entry.title,
                artist: entry.artist,
                playCountDelta: 1,
                lastPlayedTime: entry.timestamp
            )
        }
        manager.addPendingScrobbles(pending)

        // Archive the log so we don't import the same plays twice
        let archived = logURL.deletingLastPathComponent().appendingPathComponent(".scrobbler.log.imported")
        try? FileManager.default.removeItem(at: archived)
        try? FileManager.default.moveItem(at: logURL, to: archived)

        return pending.count
    }

    /// Copy library files unconverted into the Rockbox-readable /Music folder
    /// as Music/Artist/Album/Title.ext. Returns (copied, skipped).
    nonisolated static func copyFiles(tracks: [(source: URL, artist: String, album: String, title: String)], mountpoint: String) -> (copied: Int, skipped: Int) {
        let musicRoot = URL(fileURLWithPath: mountpoint).appendingPathComponent("Music", isDirectory: true)
        var copied = 0
        var skipped = 0
        for track in tracks {
            guard FileManager.default.fileExists(atPath: track.source.path) else { skipped += 1; continue }
            let dir = musicRoot
                .appendingPathComponent(IPodExporter.sanitize(track.artist), isDirectory: true)
                .appendingPathComponent(IPodExporter.sanitize(track.album), isDirectory: true)
            let ext = track.source.pathExtension.isEmpty ? "mp3" : track.source.pathExtension
            let dest = dir.appendingPathComponent(IPodExporter.sanitize(track.title)).appendingPathExtension(ext)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.copyItem(at: track.source, to: dest)
                    copied += 1
                } else {
                    skipped += 1
                }
            } catch {
                skipped += 1
            }
        }
        return (copied, skipped)
    }
}
