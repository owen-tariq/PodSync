import SwiftUI

/// Copies music OFF the iPod back to the Mac, rebuilding a readable
/// Artist/Album/NN Title.ext folder structure from the database metadata
/// (the files on the device itself have scrambled four-letter names).
@MainActor
final class IPodExporter: ObservableObject {
    static let shared = IPodExporter()

    @Published private(set) var isRunning = false
    @Published private(set) var progress = 0
    @Published private(set) var total = 0
    @Published var summary: String? = nil

    private init() {}

    nonisolated static func sanitize(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "_")
        return cleaned.isEmpty ? "Unknown" : cleaned
    }

    /// Destination path (relative to the export root) for one track.
    nonisolated static func relativePath(for track: TrackModel) -> String {
        let artist = sanitize(track.displayArtist)
        let album = sanitize(track.displayAlbum)
        let number = track.trackNumber.map { String(format: "%02d ", $0) } ?? ""
        let ext = track.filePath.pathExtension.isEmpty ? "mp3" : track.filePath.pathExtension
        let title = sanitize(track.displayTitle)
        return "\(artist)/\(album)/\(number)\(title).\(ext)"
    }

    /// Copy tracks from the iPod to a folder on the Mac.
    /// Returns the relative paths written, in input order (for M3U building).
    func export(tracks: [TrackModel], to root: URL) async -> [String] {
        guard !isRunning else { return [] }
        isRunning = true
        defer { isRunning = false }

        total = tracks.count
        progress = 0
        var written: [String] = []
        var copied = 0
        var skipped = 0

        for track in tracks {
            defer { progress += 1 }
            guard FileManager.default.fileExists(atPath: track.filePath.path) else {
                skipped += 1
                continue
            }
            let rel = Self.relativePath(for: track)
            let dest = root.appendingPathComponent(rel)
            do {
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.copyItem(at: track.filePath, to: dest)
                    copied += 1
                }
                written.append(rel)
            } catch {
                skipped += 1
            }
            // Yield so the progress UI can update
            await Task.yield()
        }

        summary = "Copied \(copied) tracks to \(root.lastPathComponent)" + (skipped > 0 ? " (\(skipped) skipped)" : "")
        return written
    }

    /// Export a playlist's tracks as files plus an .m3u8 referencing them.
    func exportPlaylist(name: String, tracks: [TrackModel], to root: URL) async {
        let relPaths = await export(tracks: tracks, to: root)
        let m3u = M3U.generate(entries: zip(tracks, relPaths).map { (track, rel) in
            M3U.Entry(seconds: Int(track.duration), artist: track.displayArtist, title: track.displayTitle, path: rel)
        })
        let m3uURL = root.appendingPathComponent("\(Self.sanitize(name)).m3u8")
        try? m3u.data(using: .utf8)?.write(to: m3uURL)
        summary = (summary ?? "") + " · playlist saved as \(m3uURL.lastPathComponent)"
    }
}

/// Minimal M3U8 read/write. Pure logic, unit-testable.
enum M3U {
    struct Entry: Equatable {
        var seconds: Int
        var artist: String
        var title: String
        var path: String
    }

    static func generate(entries: [Entry]) -> String {
        var lines = ["#EXTM3U"]
        for e in entries {
            lines.append("#EXTINF:\(e.seconds),\(e.artist) - \(e.title)")
            lines.append(e.path)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Parse an M3U/M3U8 file into entries. Tolerates plain path-only lists.
    static func parse(_ text: String) -> [Entry] {
        var entries: [Entry] = []
        var pendingInfo: (seconds: Int, artist: String, title: String)? = nil

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, line != "#EXTM3U" else { continue }

            if line.hasPrefix("#EXTINF:") {
                let body = String(line.dropFirst("#EXTINF:".count))
                let parts = body.split(separator: ",", maxSplits: 1).map(String.init)
                let seconds = Int(parts.first?.split(separator: " ").first.map(String.init) ?? "") ?? 0
                var artist = ""
                var title = parts.count > 1 ? parts[1] : ""
                if let range = title.range(of: " - ") {
                    artist = String(title[..<range.lowerBound])
                    title = String(title[range.upperBound...])
                }
                pendingInfo = (seconds, artist, title)
            } else if !line.hasPrefix("#") {
                let info = pendingInfo ?? (0, "", "")
                let stem = (line as NSString).lastPathComponent
                let fallbackTitle = (stem as NSString).deletingPathExtension
                entries.append(Entry(
                    seconds: info.seconds,
                    artist: info.artist,
                    title: info.title.isEmpty ? fallbackTitle : info.title,
                    path: line
                ))
                pendingInfo = nil
            }
        }
        return entries
    }
}
