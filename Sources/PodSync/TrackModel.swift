import Foundation

/// Represents a single music track in the library.
struct TrackModel: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    let filePath: URL
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval
    var fileSize: Int64
    var fileFormat: String
    var dateAdded: Date
    var artworkData: Data?

    // Used when track is loaded directly from an iPod database
    var ipodTrackId: UInt32? = nil

    /// Returns the duration formatted as MM:SS.
    var durationFormatted: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Returns a human-readable file size (e.g. "3.4 MB").
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    init(
        id: UUID = UUID(),
        filePath: URL,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        fileFormat: String = "",
        dateAdded: Date = Date(),
        artworkData: Data? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.fileSize = fileSize
        self.fileFormat = fileFormat
        self.dateAdded = dateAdded
        self.artworkData = artworkData
    }
}
