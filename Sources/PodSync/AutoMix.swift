import Foundation

/// Deterministic pseudo-random generator (SplitMix64) so mixes are stable
/// for a given seed (e.g. the same "Daily Mix" all day) and unit-testable.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A generated mix, ready to be materialized as an iPod playlist.
struct AutoMix: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let subtitle: String
    let icon: String
    let tracks: [TrackModel]
}

/// Local "Genius"-style playlist generation. No cloud service required —
/// mixes are built from what's already on the iPod using genre/artist
/// clustering, ratings, play counts, and era similarity, with a
/// deterministic daily shuffle so mixes refresh every day like Spotify's.
enum AutoMixEngine {

    static let defaultMixSize = 25

    /// Seed that changes once per day (so "Daily Mix" is stable all day but
    /// different tomorrow).
    static func dailySeed(for date: Date = Date()) -> UInt64 {
        let comps = Calendar.current.dateComponents([.year, .dayOfYear], from: date)
        return UInt64((comps.year ?? 0) * 1000 + (comps.dayOfYear ?? 0))
    }

    // MARK: - Scoring helpers

    /// A track's "love score": how much the user seems to like it.
    private static func loveScore(_ t: TrackModel) -> Double {
        Double(t.starRating) * 2.0 + min(10.0, Double(t.playCount)) * 0.8
    }

    /// Weighted shuffle: higher-weight tracks are more likely to appear early.
    static func weightedShuffle(_ tracks: [TrackModel], weight: (TrackModel) -> Double, seed: UInt64) -> [TrackModel] {
        var rng = SeededRandom(seed: seed)
        return tracks
            .map { track -> (TrackModel, Double) in
                let w = max(0.1, weight(track))
                // Efraimidis-Spirakis: key = u^(1/w)
                let u = Double(rng.next() % 1_000_000) / 1_000_000.0
                let key = pow(max(u, 0.000001), 1.0 / w)
                return (track, key)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    private static func musicOnly(_ tracks: [TrackModel]) -> [TrackModel] {
        tracks.filter { $0.ipodMediaType == 1 || $0.ipodMediaType == 0 || $0.ipodMediaType == nil }
    }

    // MARK: - Daily Mixes (genre/artist clusters)

    /// Cluster tracks by genre (falling back to artist when genre is missing)
    /// and return the biggest clusters as Daily Mixes.
    static func dailyMixes(tracks: [TrackModel], count: Int = 3, size: Int = defaultMixSize, seed: UInt64? = nil) -> [AutoMix] {
        let music = musicOnly(tracks)
        guard music.count >= 10 else { return [] }
        let daySeed = seed ?? dailySeed()

        var clusters: [String: [TrackModel]] = [:]
        for track in music {
            let key: String
            if let genre = track.genre, !genre.isEmpty {
                key = genre
            } else {
                key = track.displayArtist
            }
            clusters[key, default: []].append(track)
        }

        // Biggest clusters first; require at least 5 tracks to make a mix
        let ranked = clusters
            .filter { $0.value.count >= 5 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(count)

        return ranked.enumerated().map { (index, entry) in
            let (label, clusterTracks) = entry
            let shuffled = weightedShuffle(clusterTracks, weight: { 1.0 + loveScore($0) }, seed: daySeed &+ UInt64(index))
            return AutoMix(
                name: "Daily Mix \(index + 1)",
                subtitle: label,
                icon: "square.stack.3d.up.fill",
                tracks: Array(shuffled.prefix(size))
            )
        }
    }

    // MARK: - Discover Weekly (least played)

    /// Tracks the user rarely/never plays — resurface forgotten music.
    /// Spotify equivalent: Discover Weekly.
    static func discoveryMix(tracks: [TrackModel], size: Int = defaultMixSize, seed: UInt64? = nil) -> AutoMix? {
        let music = musicOnly(tracks)
        guard music.count >= 10 else { return nil }
        let daySeed = (seed ?? dailySeed()) &+ 777

        let neglected = music.sorted { $0.playCount < $1.playCount }
        let pool = Array(neglected.prefix(max(size * 3, music.count / 2)))
        let shuffled = weightedShuffle(pool, weight: { 1.0 + Double(5 - min(5, $0.playCount)) }, seed: daySeed)

        return AutoMix(
            name: "Discover Weekly",
            subtitle: "Songs you haven't played much — your weekly rediscovery mix",
            icon: "sparkles",
            tracks: Array(shuffled.prefix(size))
        )
    }

    // MARK: - Release Radar (recently added)

    /// Newest additions to the device — Spotify equivalent: Release Radar.
    static func releaseRadar(tracks: [TrackModel], size: Int = defaultMixSize, seed: UInt64? = nil, now: Date = Date()) -> AutoMix? {
        let music = musicOnly(tracks)
        guard music.count >= 10 else { return nil }
        let daySeed = (seed ?? dailySeed()) &+ 3030

        let cutoff = now.addingTimeInterval(-30 * 86400)
        var recent = music.filter { $0.dateAdded >= cutoff }
        if recent.count < 5 {
            // Fall back to the most recently added tracks overall
            recent = Array(music.sorted { $0.dateAdded > $1.dateAdded }.prefix(size))
        }
        let shuffled = weightedShuffle(recent, weight: { 1.0 + loveScore($0) }, seed: daySeed)
        return AutoMix(
            name: "Release Radar",
            subtitle: "Your newest additions",
            icon: "dot.radiowaves.left.and.right",
            tracks: Array(shuffled.prefix(size))
        )
    }

    // MARK: - On Repeat (current favorites)

    /// Spotify equivalent: On Repeat — the songs you can't stop playing.
    static func onRepeatMix(tracks: [TrackModel], size: Int = defaultMixSize, seed: UInt64? = nil) -> AutoMix? {
        let music = musicOnly(tracks)
        guard music.count >= 10 else { return nil }
        let daySeed = (seed ?? dailySeed()) &+ 4242

        let loved = music.filter { loveScore($0) > 0 }
        guard loved.count >= 5 else { return nil }
        let shuffled = weightedShuffle(loved, weight: { loveScore($0) }, seed: daySeed)

        return AutoMix(
            name: "On Repeat",
            subtitle: "The songs you can't stop playing",
            icon: "repeat",
            tracks: Array(shuffled.prefix(size))
        )
    }

    // MARK: - Repeat Rewind (old favorites)

    /// Spotify equivalent: Repeat Rewind — songs you used to have on repeat.
    static func repeatRewindMix(tracks: [TrackModel], size: Int = defaultMixSize, seed: UInt64? = nil, now: Date = Date()) -> AutoMix? {
        let music = musicOnly(tracks)
        guard music.count >= 10 else { return nil }
        let daySeed = (seed ?? dailySeed()) &+ 8686

        let cutoff = now.addingTimeInterval(-90 * 86400)
        let oldFavorites = music.filter { $0.playCount >= 2 && $0.dateAdded < cutoff }
        guard oldFavorites.count >= 5 else { return nil }
        let shuffled = weightedShuffle(oldFavorites, weight: { loveScore($0) }, seed: daySeed)
        return AutoMix(
            name: "Repeat Rewind",
            subtitle: "Songs you used to have on repeat",
            icon: "arrow.uturn.backward.circle",
            tracks: Array(shuffled.prefix(size))
        )
    }

    // MARK: - Time Capsule (older eras)

    /// Spotify equivalent: Your Time Capsule.
    static func throwbackMix(tracks: [TrackModel], size: Int = defaultMixSize, seed: UInt64? = nil) -> AutoMix? {
        let music = musicOnly(tracks).filter { $0.yearValue > 0 }
        guard music.count >= 10 else { return nil }
        let daySeed = (seed ?? dailySeed()) &+ 1999

        let years = music.map { $0.yearValue }.sorted()
        let medianYear = years[years.count / 2]
        let throwbacks = music.filter { $0.yearValue < medianYear }
        guard throwbacks.count >= 5 else { return nil }

        let shuffled = weightedShuffle(throwbacks, weight: { 1.0 + loveScore($0) }, seed: daySeed)
        return AutoMix(
            name: "Your Time Capsule",
            subtitle: "Older favorites (pre-\(medianYear))",
            icon: "clock.arrow.circlepath",
            tracks: Array(shuffled.prefix(size))
        )
    }

    // MARK: - Your Top Songs

    /// Spotify equivalent: "Your Top Songs" wrapped playlist — pure ranking, no shuffle.
    static func topSongsMix(tracks: [TrackModel], size: Int = defaultMixSize) -> AutoMix? {
        let music = musicOnly(tracks)
        guard music.count >= 10 else { return nil }
        let ranked = music
            .filter { loveScore($0) > 0 }
            .sorted { loveScore($0) > loveScore($1) }
        guard ranked.count >= 5 else { return nil }
        let year = Calendar.current.component(.year, from: Date())
        return AutoMix(
            name: "Your Top Songs \(year)",
            subtitle: "Your most loved tracks, ranked",
            icon: "trophy.fill",
            tracks: Array(ranked.prefix(size))
        )
    }

    // MARK: - Decade Mixes

    /// Spotify equivalents: "80s Mix", "90s Mix", "2000s Mix"...
    static func decadeMixes(tracks: [TrackModel], size: Int = defaultMixSize, seed: UInt64? = nil, maxMixes: Int = 3) -> [AutoMix] {
        let music = musicOnly(tracks).filter { $0.yearValue > 0 }
        guard music.count >= 10 else { return [] }
        let daySeed = seed ?? dailySeed()

        var byDecade: [Int: [TrackModel]] = [:]
        for track in music {
            let decade = (track.yearValue / 10) * 10
            byDecade[decade, default: []].append(track)
        }

        let ranked = byDecade
            .filter { $0.value.count >= 8 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(maxMixes)

        return ranked.map { (decade, decadeTracks) in
            let label = decade >= 2000 ? "\(decade)s" : "\(decade % 100)s"
            let shuffled = weightedShuffle(decadeTracks, weight: { 1.0 + loveScore($0) }, seed: daySeed &+ UInt64(decade))
            return AutoMix(
                name: "\(label) Mix",
                subtitle: "The best of your \(label) collection",
                icon: "calendar",
                tracks: Array(shuffled.prefix(size))
            )
        }
    }

    // MARK: - Artist Mixes

    /// Spotify equivalents: "This Is X" / artist mixes for your most-collected artists.
    static func artistMixes(tracks: [TrackModel], size: Int = defaultMixSize, seed: UInt64? = nil, maxMixes: Int = 2) -> [AutoMix] {
        let music = musicOnly(tracks)
        guard music.count >= 10 else { return [] }
        let daySeed = seed ?? dailySeed()

        let byArtist = Dictionary(grouping: music, by: { $0.displayArtist })
            .filter { $0.key != "Unknown Artist" && $0.value.count >= 8 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(maxMixes)

        return byArtist.enumerated().map { (index, entry) in
            let (artist, artistTracks) = entry
            let shuffled = weightedShuffle(artistTracks, weight: { 1.0 + loveScore($0) }, seed: daySeed &+ UInt64(9000 + index))
            return AutoMix(
                name: "This Is \(artist)",
                subtitle: "Essential \(artist)",
                icon: "person.wave.2.fill",
                tracks: Array(shuffled.prefix(size))
            )
        }
    }

    // MARK: - Genius from a seed track

    /// Similarity score between a seed track and a candidate — the heart of
    /// the local Genius feature.
    static func similarity(seed: TrackModel, candidate: TrackModel) -> Double {
        var score = 0.0
        if candidate.displayArtist.caseInsensitiveCompare(seed.displayArtist) == .orderedSame { score += 5.0 }
        if let sg = seed.genre, let cg = candidate.genre, !sg.isEmpty,
           sg.caseInsensitiveCompare(cg) == .orderedSame { score += 4.0 }
        if candidate.displayAlbum.caseInsensitiveCompare(seed.displayAlbum) == .orderedSame { score += 1.5 }
        if let sa = seed.albumArtist, let ca = candidate.albumArtist, !sa.isEmpty,
           sa.caseInsensitiveCompare(ca) == .orderedSame { score += 2.0 }
        if seed.yearValue > 0 && candidate.yearValue > 0 {
            let gap = abs(seed.yearValue - candidate.yearValue)
            if gap <= 3 { score += 2.0 }
            else if gap <= 8 { score += 1.0 }
        }
        // Liked songs get a slight boost so the mix leans on quality
        score += loveScore(candidate) * 0.15
        return score
    }

    /// Build a Genius-style mix from a seed track.
    static func geniusMix(seed: TrackModel, tracks: [TrackModel], size: Int = defaultMixSize, randomSeed: UInt64? = nil) -> AutoMix {
        let music = musicOnly(tracks).filter { $0.id != seed.id }
        let scored = music
            .map { ($0, similarity(seed: seed, candidate: $0)) }
            .filter { $0.1 > 0.5 }
            .sorted { $0.1 > $1.1 }

        // Take a generous pool of the most similar, then weighted-shuffle for variety
        let pool = Array(scored.prefix(size * 3))
        let shuffled = weightedShuffle(pool.map { $0.0 }, weight: { candidate in
            1.0 + (scored.first { $0.0.id == candidate.id }?.1 ?? 0)
        }, seed: randomSeed ?? dailySeed())

        var mixTracks = [seed]
        mixTracks.append(contentsOf: shuffled.prefix(size - 1))

        return AutoMix(
            name: "Genius — \(seed.displayTitle)",
            subtitle: "Based on \(seed.displayTitle) by \(seed.displayArtist)",
            icon: "wand.and.stars",
            tracks: mixTracks
        )
    }

    // MARK: - All standard mixes

    /// Generate the full set of standard mixes for a library — the whole
    /// Spotify-style lineup, built locally from the iPod's own library.
    static func generateAll(tracks: [TrackModel], seed: UInt64? = nil) -> [AutoMix] {
        var mixes: [AutoMix] = []
        mixes.append(contentsOf: dailyMixes(tracks: tracks, count: 4, seed: seed))
        if let discovery = discoveryMix(tracks: tracks, seed: seed) { mixes.append(discovery) }
        if let radar = releaseRadar(tracks: tracks, seed: seed) { mixes.append(radar) }
        if let onRepeat = onRepeatMix(tracks: tracks, seed: seed) { mixes.append(onRepeat) }
        if let rewind = repeatRewindMix(tracks: tracks, seed: seed) { mixes.append(rewind) }
        if let capsule = throwbackMix(tracks: tracks, seed: seed) { mixes.append(capsule) }
        if let top = topSongsMix(tracks: tracks) { mixes.append(top) }
        mixes.append(contentsOf: decadeMixes(tracks: tracks, seed: seed))
        mixes.append(contentsOf: artistMixes(tracks: tracks, seed: seed))
        return mixes
    }
}

// MARK: - Applying mixes to the iPod

@MainActor
enum AutoMixApplier {
    /// Materialize a mix as a real playlist on the iPod (creating or replacing it).
    @discardableResult
    static func apply(_ mix: AutoMix, to ipodManager: IPodManager) -> Int {
        let ids = mix.tracks.compactMap { $0.ipodTrackId }
        if ipodManager.playlistNamed(mix.name) == nil {
            ipodManager.createPlaylist(name: mix.name)
        }
        guard let target = ipodManager.playlistNamed(mix.name) else { return 0 }
        ipodManager.setPlaylistContents(playlistId: target.id, ipodTrackIds: ids)
        return ids.count
    }

    /// Generate and apply all standard mixes. Returns (mixCount, trackCount).
    @discardableResult
    static func refreshAllMixes(ipodManager: IPodManager) -> (mixes: Int, tracks: Int) {
        let mixes = AutoMixEngine.generateAll(tracks: ipodManager.deviceTracks)
        var total = 0
        for mix in mixes {
            total += apply(mix, to: ipodManager)
        }
        return (mixes.count, total)
    }
}
