import Foundation

/// A rule-based smart playlist evaluated against the device library and
/// materialized as a regular playlist on the iPod when applied.
struct SmartPlaylist: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var matchAll: Bool = true // true = ALL rules must match, false = ANY
    var rules: [SmartRule] = []
    /// Optional cap on number of tracks (applied after sorting by the sort field)
    var limit: Int? = nil
    var sortField: SortField = .artist

    enum SortField: String, Codable, CaseIterable, Sendable {
        case title, artist, album, year, rating, playCount, dateAdded

        var label: String {
            switch self {
            case .title: return "Title"
            case .artist: return "Artist"
            case .album: return "Album"
            case .year: return "Year"
            case .rating: return "Rating"
            case .playCount: return "Play Count"
            case .dateAdded: return "Date Added"
            }
        }
    }

    /// Evaluate this smart playlist against a set of tracks.
    func evaluate(tracks: [TrackModel]) -> [TrackModel] {
        var matched = tracks.filter { track in
            guard !rules.isEmpty else { return true }
            if matchAll {
                return rules.allSatisfy { $0.matches(track) }
            } else {
                return rules.contains { $0.matches(track) }
            }
        }

        matched.sort { a, b in
            switch sortField {
            case .title: return a.displayTitle.localizedCaseInsensitiveCompare(b.displayTitle) == .orderedAscending
            case .artist: return a.displayArtist.localizedCaseInsensitiveCompare(b.displayArtist) == .orderedAscending
            case .album: return a.displayAlbum.localizedCaseInsensitiveCompare(b.displayAlbum) == .orderedAscending
            case .year: return a.yearValue > b.yearValue
            case .rating: return a.rating > b.rating
            case .playCount: return a.playCount > b.playCount
            case .dateAdded: return a.dateAdded > b.dateAdded
            }
        }

        if let limit = limit, limit > 0, matched.count > limit {
            matched = Array(matched.prefix(limit))
        }
        return matched
    }
}

/// A single rule inside a smart playlist.
struct SmartRule: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var field: Field = .artist
    var op: Operator = .contains
    var value: String = ""

    enum Field: String, Codable, CaseIterable, Sendable {
        case title, artist, album, albumArtist, genre, year, rating, playCount

        var label: String {
            switch self {
            case .title: return "Title"
            case .artist: return "Artist"
            case .album: return "Album"
            case .albumArtist: return "Album Artist"
            case .genre: return "Genre"
            case .year: return "Year"
            case .rating: return "Rating (stars)"
            case .playCount: return "Play Count"
            }
        }

        var isNumeric: Bool {
            switch self {
            case .year, .rating, .playCount: return true
            default: return false
            }
        }
    }

    enum Operator: String, Codable, CaseIterable, Sendable {
        case contains
        case doesNotContain
        case isEqual
        case isNot
        case greaterThan
        case lessThan

        var label: String {
            switch self {
            case .contains: return "contains"
            case .doesNotContain: return "does not contain"
            case .isEqual: return "is"
            case .isNot: return "is not"
            case .greaterThan: return "is greater than"
            case .lessThan: return "is less than"
            }
        }

        static func valid(for field: Field) -> [Operator] {
            field.isNumeric
                ? [.isEqual, .isNot, .greaterThan, .lessThan]
                : [.contains, .doesNotContain, .isEqual, .isNot]
        }
    }

    func matches(_ track: TrackModel) -> Bool {
        if field.isNumeric {
            let trackValue: Int
            switch field {
            case .year: trackValue = track.yearValue
            case .rating: trackValue = track.starRating
            case .playCount: trackValue = track.playCount
            default: trackValue = 0
            }
            guard let ruleValue = Int(value.trimmingCharacters(in: .whitespaces)) else { return false }
            switch op {
            case .isEqual: return trackValue == ruleValue
            case .isNot: return trackValue != ruleValue
            case .greaterThan: return trackValue > ruleValue
            case .lessThan: return trackValue < ruleValue
            default: return false
            }
        } else {
            let trackValue: String
            switch field {
            case .title: trackValue = track.displayTitle
            case .artist: trackValue = track.displayArtist
            case .album: trackValue = track.displayAlbum
            case .albumArtist: trackValue = track.albumArtist ?? ""
            case .genre: trackValue = track.displayGenre
            default: trackValue = ""
            }
            let needle = value.trimmingCharacters(in: .whitespaces)
            guard !needle.isEmpty else { return false }
            switch op {
            case .contains: return trackValue.localizedCaseInsensitiveContains(needle)
            case .doesNotContain: return !trackValue.localizedCaseInsensitiveContains(needle)
            case .isEqual: return trackValue.caseInsensitiveCompare(needle) == .orderedSame
            case .isNot: return trackValue.caseInsensitiveCompare(needle) != .orderedSame
            default: return false
            }
        }
    }
}

/// Persists smart playlist definitions on the Mac (they are materialized to
/// the iPod as regular playlists when applied).
@MainActor
final class SmartPlaylistStore: ObservableObject {
    static let shared = SmartPlaylistStore()

    @Published private(set) var smartPlaylists: [SmartPlaylist] = []

    private let storageKey = "podsync.smartPlaylists"

    private init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SmartPlaylist].self, from: data) else { return }
        smartPlaylists = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(smartPlaylists) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func upsert(_ playlist: SmartPlaylist) {
        if let idx = smartPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            smartPlaylists[idx] = playlist
        } else {
            smartPlaylists.append(playlist)
        }
        persist()
    }

    func delete(id: UUID) {
        smartPlaylists.removeAll { $0.id == id }
        persist()
    }

    /// Materialize a smart playlist onto the connected iPod as a regular playlist.
    /// Creates the playlist if needed, otherwise replaces its contents.
    @discardableResult
    func apply(_ playlist: SmartPlaylist, to ipodManager: IPodManager) -> Int {
        let matched = playlist.evaluate(tracks: ipodManager.deviceTracks)
        let ids = matched.compactMap { $0.ipodTrackId }

        if ipodManager.playlistNamed(playlist.name) == nil {
            ipodManager.createPlaylist(name: playlist.name)
        }
        guard let target = ipodManager.playlistNamed(playlist.name) else { return 0 }
        ipodManager.setPlaylistContents(playlistId: target.id, ipodTrackIds: ids)
        return ids.count
    }
}
