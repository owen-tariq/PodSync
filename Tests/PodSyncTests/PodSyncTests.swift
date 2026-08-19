import Testing
import Foundation
@testable import PodSync

// MARK: - Helpers

private func makeTrack(
    title: String = "Song",
    artist: String = "Artist",
    album: String = "Album",
    genre: String? = nil,
    year: Int? = nil,
    rating: Int = 0,
    playCount: Int = 0
) -> TrackModel {
    var t = TrackModel(
        filePath: URL(fileURLWithPath: "/dev/null"),
        title: title,
        artist: artist,
        album: album,
        genre: genre,
        year: year
    )
    t.rating = rating
    t.playCount = playCount
    return t
}

// MARK: - Smart Playlist rules

@Test func smartRuleContainsMatchesCaseInsensitive() {
    let rule = SmartRule(field: .artist, op: .contains, value: "daft")
    #expect(rule.matches(makeTrack(artist: "Daft Punk")))
    #expect(!rule.matches(makeTrack(artist: "Justice")))
}

@Test func smartRuleNumericComparisons() {
    let newer = SmartRule(field: .year, op: .greaterThan, value: "2000")
    #expect(newer.matches(makeTrack(year: 2013)))
    #expect(!newer.matches(makeTrack(year: 1997)))

    let fiveStars = SmartRule(field: .rating, op: .isEqual, value: "5")
    #expect(fiveStars.matches(makeTrack(rating: 100)))
    #expect(!fiveStars.matches(makeTrack(rating: 60)))
}

@Test func smartPlaylistMatchAllVsAny() {
    let tracks = [
        makeTrack(title: "One", artist: "Daft Punk", genre: "Electronic"),
        makeTrack(title: "Two", artist: "Daft Punk", genre: "Rock"),
        makeTrack(title: "Three", artist: "Queen", genre: "Rock")
    ]
    let rules = [
        SmartRule(field: .artist, op: .contains, value: "Daft"),
        SmartRule(field: .genre, op: .isEqual, value: "Rock")
    ]

    var all = SmartPlaylist(name: "All", matchAll: true, rules: rules)
    #expect(all.evaluate(tracks: tracks).map(\.displayTitle) == ["Two"])

    all.matchAll = false
    #expect(all.evaluate(tracks: tracks).count == 3)
}

@Test func smartPlaylistLimitAndSort() {
    let tracks = (1...10).map { makeTrack(title: "T\($0)", playCount: $0) }
    let playlist = SmartPlaylist(name: "Top 3", matchAll: true, rules: [], limit: 3, sortField: .playCount)
    let result = playlist.evaluate(tracks: tracks)
    #expect(result.count == 3)
    #expect(result.map(\.playCount) == [10, 9, 8])
}

@Test func smartPlaylistEmptyRulesMatchesEverything() {
    let tracks = [makeTrack(title: "A"), makeTrack(title: "B")]
    let playlist = SmartPlaylist(name: "Everything", rules: [])
    #expect(playlist.evaluate(tracks: tracks).count == 2)
}

// MARK: - RSS feed parsing

private let sampleFeed = """
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Show</title>
    <description>A show about testing.</description>
    <itunes:author>Test Author</itunes:author>
    <itunes:image href="https://example.com/art.jpg"/>
    <item>
      <title>Episode 2</title>
      <guid>ep-2</guid>
      <description><![CDATA[<p>Second &amp; best episode</p>]]></description>
      <pubDate>Tue, 12 Aug 2025 10:00:00 +0000</pubDate>
      <itunes:duration>1:02:03</itunes:duration>
      <enclosure url="https://example.com/ep2.mp3" length="52428800" type="audio/mpeg"/>
    </item>
    <item>
      <title>Episode 1</title>
      <guid>ep-1</guid>
      <pubDate>Mon, 04 Aug 2025 08:30:00 +0000</pubDate>
      <itunes:duration>1800</itunes:duration>
      <enclosure url="https://example.com/ep1.mp3" length="26214400" type="audio/mpeg"/>
    </item>
    <item>
      <title>No enclosure — should be skipped</title>
      <guid>ep-0</guid>
    </item>
  </channel>
</rss>
"""

@Test func rssParserExtractsShowAndEpisodes() throws {
    let data = try #require(sampleFeed.data(using: .utf8))
    let feed = try #require(PodcastFeedParser.parse(data: data, feedURL: "https://example.com/feed.xml"))

    #expect(feed.title == "Test Show")
    #expect(feed.author == "Test Author")
    #expect(feed.artworkURL == "https://example.com/art.jpg")
    #expect(feed.episodes.count == 2) // item without enclosure skipped

    let ep2 = feed.episodes[0]
    #expect(ep2.title == "Episode 2")
    #expect(ep2.guid == "ep-2")
    #expect(ep2.enclosureURL == "https://example.com/ep2.mp3")
    #expect(ep2.fileSize == 52_428_800)
    #expect(ep2.duration == 3723)
    #expect(ep2.episodeDescription == "Second & best episode")
    #expect(ep2.pubDate != nil)
}

@Test func rssParserRejectsGarbage() {
    let notXML = Data("this is not a feed".utf8)
    #expect(PodcastFeedParser.parse(data: notXML, feedURL: "x") == nil)
}

@Test func durationParsing() {
    #expect(PodcastFeedParser.parseDuration("3723") == 3723)
    #expect(PodcastFeedParser.parseDuration("1:02:03") == 3723)
    #expect(PodcastFeedParser.parseDuration("62:03") == 3723)
    #expect(PodcastFeedParser.parseDuration("") == nil)
    #expect(PodcastFeedParser.parseDuration("abc") == nil)
}

@Test func rfc822DateParsing() {
    let d = PodcastFeedParser.parseDate("Tue, 12 Aug 2025 10:00:00 +0000")
    #expect(d != nil)
    let noDay = PodcastFeedParser.parseDate("12 Aug 2025 10:00:00 GMT")
    #expect(noDay != nil)
    #expect(PodcastFeedParser.parseDate("not a date") == nil)
}

// MARK: - Podcast retention

@Test func retentionKeepsNewestEpisodes() {
    let now = Date()
    let episodes: [(id: String, releaseDate: Date?)] = [
        ("old", now.addingTimeInterval(-4 * 86400)),
        ("newest", now),
        ("older", now.addingTimeInterval(-8 * 86400)),
        ("new", now.addingTimeInterval(-1 * 86400))
    ]
    let removals = PodcastRetention.episodesToRemove(deviceEpisodes: episodes, keepLatest: 2)
    #expect(Set(removals) == Set(["old", "older"]))
}

@Test func retentionNoRemovalWhenUnderLimit() {
    let episodes: [(id: String, releaseDate: Date?)] = [("a", Date()), ("b", Date())]
    #expect(PodcastRetention.episodesToRemove(deviceEpisodes: episodes, keepLatest: 5).isEmpty)
    #expect(PodcastRetention.episodesToRemove(deviceEpisodes: episodes, keepLatest: 0).isEmpty)
}

@Test func retentionTreatsUndatedAsOldest() {
    let episodes: [(id: String, releaseDate: Date?)] = [
        ("dated", Date()),
        ("undated", nil)
    ]
    let removals = PodcastRetention.episodesToRemove(deviceEpisodes: episodes, keepLatest: 1)
    #expect(removals == ["undated"])
}

// MARK: - Conversion routing

@Test func conversionClassification() {
    #expect(!AudioConverter.needsConversion(url: URL(fileURLWithPath: "/x/song.mp3")))
    #expect(!AudioConverter.needsConversion(url: URL(fileURLWithPath: "/x/song.m4a")))
    #expect(AudioConverter.needsConversion(url: URL(fileURLWithPath: "/x/song.flac")))
    #expect(AudioConverter.needsConversion(url: URL(fileURLWithPath: "/x/song.ogg")))
    #expect(AudioConverter.needsConversion(url: URL(fileURLWithPath: "/x/song.opus")))
}

@Test func trackModelStarRating() {
    var t = makeTrack(rating: 100)
    #expect(t.starRating == 5)
    t.rating = 60
    #expect(t.starRating == 3)
    t.rating = 0
    #expect(t.starRating == 0)
    t.rating = 999
    #expect(t.starRating == 5)
}

// MARK: - Auto Mix engine

private func makeLibrary() -> [TrackModel] {
    var tracks: [TrackModel] = []
    // 20 rock tracks by 4 artists, 15 electronic tracks by 3 artists
    for i in 1...20 {
        var t = makeTrack(title: "Rock \(i)", artist: "RockBand \(i % 4)", album: "RockAlbum \(i % 5)",
                          genre: "Rock", year: 1990 + (i % 20), rating: (i % 6) * 20, playCount: i % 8)
        t.ipodMediaType = 1
        tracks.append(t)
    }
    for i in 1...15 {
        var t = makeTrack(title: "Elec \(i)", artist: "DJ \(i % 3)", album: "ElecAlbum \(i % 4)",
                          genre: "Electronic", year: 2005 + (i % 15), rating: (i % 6) * 20, playCount: i % 5)
        t.ipodMediaType = 1
        tracks.append(t)
    }
    return tracks
}

@Test func dailyMixesClusterByGenre() {
    let mixes = AutoMixEngine.dailyMixes(tracks: makeLibrary(), count: 3, seed: 42)
    #expect(mixes.count == 2) // two genres -> two mixes
    #expect(mixes[0].name == "Daily Mix 1")
    #expect(mixes[0].subtitle == "Rock") // biggest cluster first
    #expect(mixes[1].subtitle == "Electronic")
    #expect(!mixes[0].tracks.isEmpty)
    #expect(mixes[0].tracks.allSatisfy { $0.genre == "Rock" })
}

@Test func dailyMixesAreDeterministicPerSeed() {
    let library = makeLibrary()
    let a = AutoMixEngine.dailyMixes(tracks: library, seed: 7).first!
    let b = AutoMixEngine.dailyMixes(tracks: library, seed: 7).first!
    let c = AutoMixEngine.dailyMixes(tracks: library, seed: 8).first!
    #expect(a.tracks.map(\.displayTitle) == b.tracks.map(\.displayTitle))
    #expect(a.tracks.map(\.displayTitle) != c.tracks.map(\.displayTitle))
}

@Test func discoverWeeklyFavorsUnplayed() {
    var library = makeLibrary()
    for i in 0..<5 {
        library[i].playCount = 0
    }
    let mix = AutoMixEngine.discoveryMix(tracks: library, size: 10, seed: 1)
    #expect(mix != nil)
    #expect(mix!.name == "Discover Weekly")
    let avgPlays = Double(mix!.tracks.map(\.playCount).reduce(0, +)) / Double(mix!.tracks.count)
    let libAvg = Double(library.map(\.playCount).reduce(0, +)) / Double(library.count)
    #expect(avgPlays <= libAvg)
}

@Test func releaseRadarPrefersRecentlyAdded() {
    var library = makeLibrary()
    // Make 6 tracks freshly added, the rest old
    for i in 0..<library.count {
        var t = library[i]
        t.dateAdded = i < 6 ? Date() : Date().addingTimeInterval(-120 * 86400)
        library[i] = t
    }
    let mix = AutoMixEngine.releaseRadar(tracks: library, size: 6, seed: 2)
    #expect(mix != nil)
    #expect(mix!.tracks.allSatisfy { $0.dateAdded > Date().addingTimeInterval(-31 * 86400) })
}

@Test func topSongsAreRankedByLove() {
    let library = makeLibrary()
    let mix = AutoMixEngine.topSongsMix(tracks: library, size: 5)
    #expect(mix != nil)
    // First track should have max star rating among the picks
    let ratings = mix!.tracks.map(\.starRating)
    #expect(ratings.first! >= ratings.last!)
}

@Test func decadeMixesSplitByDecade() {
    let mixes = AutoMixEngine.decadeMixes(tracks: makeLibrary(), seed: 3)
    #expect(!mixes.isEmpty)
    for mix in mixes {
        #expect(mix.name.hasSuffix("Mix"))
        let decades = Set(mix.tracks.map { ($0.yearValue / 10) * 10 })
        #expect(decades.count == 1) // all tracks from one decade
    }
}

@Test func geniusMixLeadsWithSeedAndFindsSimilar() {
    let library = makeLibrary()
    let seedTrack = library[0] // Rock track
    let mix = AutoMixEngine.geniusMix(seed: seedTrack, tracks: library, size: 10, randomSeed: 3)
    #expect(mix.tracks.first?.id == seedTrack.id)
    #expect(mix.tracks.count > 1)
    let sameGenre = mix.tracks.dropFirst().filter { $0.genre == "Rock" }.count
    #expect(sameGenre >= mix.tracks.dropFirst().count / 2)
}

@Test func similarityScoring() {
    let seed = makeTrack(title: "S", artist: "Daft Punk", album: "Discovery", genre: "Electronic", year: 2001)
    let sameArtist = makeTrack(title: "A", artist: "Daft Punk", album: "Homework", genre: "Electronic", year: 1997)
    let sameGenreOnly = makeTrack(title: "B", artist: "Justice", album: "Cross", genre: "Electronic", year: 2007)
    let unrelated = makeTrack(title: "C", artist: "Slayer", album: "Reign", genre: "Metal", year: 1986)

    let a = AutoMixEngine.similarity(seed: seed, candidate: sameArtist)
    let b = AutoMixEngine.similarity(seed: seed, candidate: sameGenreOnly)
    let c = AutoMixEngine.similarity(seed: seed, candidate: unrelated)
    #expect(a > b)
    #expect(b > c)
    #expect(c < 0.5)
}

@Test func weightedShuffleRespectsSeed() {
    let tracks = (1...30).map { makeTrack(title: "T\($0)") }
    let a = AutoMixEngine.weightedShuffle(tracks, weight: { _ in 1 }, seed: 5).map(\.displayTitle)
    let b = AutoMixEngine.weightedShuffle(tracks, weight: { _ in 1 }, seed: 5).map(\.displayTitle)
    #expect(a == b)
}

@Test func generateAllProducesFullLineup() {
    let mixes = AutoMixEngine.generateAll(tracks: makeLibrary(), seed: 11)
    let names = mixes.map(\.name)
    #expect(names.contains("Daily Mix 1"))
    #expect(names.contains("Discover Weekly"))
    #expect(names.contains("Release Radar"))
    #expect(names.contains("On Repeat"))
    #expect(Set(names).count == names.count) // no duplicate playlist names
}
