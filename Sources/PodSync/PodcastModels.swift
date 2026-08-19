import Foundation

/// A podcast show the user is subscribed to.
struct PodcastSubscription: Identifiable, Codable, Hashable, Sendable {
    var id: String { feedURL }
    var feedURL: String
    var title: String
    var author: String?
    var artworkURL: String?
    var showDescription: String?
    /// Keep only the latest N episodes on the iPod when syncing (nil = keep all).
    var keepLatest: Int? = nil
    var dateSubscribed: Date = Date()
}

/// A single episode parsed from a podcast RSS feed.
struct PodcastEpisode: Identifiable, Codable, Hashable, Sendable {
    var id: String { guid }
    var guid: String
    var title: String
    var showTitle: String
    var feedURL: String
    var episodeDescription: String?
    var pubDate: Date?
    var duration: TimeInterval?
    var enclosureURL: String
    var fileSize: Int64?

    var pubDateFormatted: String {
        guard let date = pubDate else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

/// Result of searching the iTunes podcast directory.
struct PodcastSearchResult: Identifiable, Codable, Hashable, Sendable {
    var id: String { feedURL }
    var title: String
    var author: String?
    var feedURL: String
    var artworkURL: String?
    var episodeCount: Int?
    var genre: String?
}

// MARK: - RSS Feed Parsing

/// Parses a podcast RSS feed into show metadata + episodes.
/// Pure logic — unit-testable without any network access.
final class PodcastFeedParser: NSObject, XMLParserDelegate {

    struct ParsedFeed: Sendable {
        var title: String = ""
        var author: String?
        var artworkURL: String?
        var description: String?
        var episodes: [PodcastEpisode] = []
    }

    private var feed = ParsedFeed()
    private var feedURL: String = ""

    // Parsing state
    private var insideItem = false
    private var currentElement = ""
    private var currentText = ""

    private var itemTitle = ""
    private var itemGuid = ""
    private var itemDescription = ""
    private var itemPubDate: Date?
    private var itemDuration: TimeInterval?
    private var itemEnclosureURL: String?
    private var itemEnclosureLength: Int64?

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    /// Parse feed XML data. Returns nil if the XML is not a valid feed.
    static func parse(data: Data, feedURL: String) -> ParsedFeed? {
        let parser = PodcastFeedParser()
        parser.feedURL = feedURL
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse() else { return nil }
        guard !parser.feed.title.isEmpty || !parser.feed.episodes.isEmpty else { return nil }
        return parser.feed
    }

    /// Parse an RFC-822 style date used in RSS feeds.
    static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = makeFormatter("EEE, dd MMM yyyy HH:mm:ss Z").date(from: trimmed) { return d }
        if let d = makeFormatter("dd MMM yyyy HH:mm:ss Z").date(from: trimmed) { return d }
        return nil
    }

    /// Parse itunes:duration values: "3723", "1:02:03", "62:03"
    static func parseDuration(_ string: String) -> TimeInterval? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":").map(String.init)
        if parts.count == 1 {
            return TimeInterval(parts[0])
        }
        var seconds: TimeInterval = 0
        for part in parts {
            guard let v = TimeInterval(part) else { return nil }
            seconds = seconds * 60 + v
        }
        return seconds
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "item":
            insideItem = true
            itemTitle = ""
            itemGuid = ""
            itemDescription = ""
            itemPubDate = nil
            itemDuration = nil
            itemEnclosureURL = nil
            itemEnclosureLength = nil
        case "enclosure":
            if insideItem {
                itemEnclosureURL = attributeDict["url"]
                itemEnclosureLength = attributeDict["length"].flatMap { Int64($0) }
            }
        case "itunes:image":
            if !insideItem, feed.artworkURL == nil {
                feed.artworkURL = attributeDict["href"]
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            currentText += s
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if insideItem {
            switch elementName {
            case "title": itemTitle = text
            case "guid": itemGuid = text
            case "description":
                if itemDescription.isEmpty { itemDescription = text }
            case "itunes:summary":
                if itemDescription.isEmpty { itemDescription = text }
            case "pubDate": itemPubDate = Self.parseDate(text)
            case "itunes:duration": itemDuration = Self.parseDuration(text)
            case "item":
                insideItem = false
                if let enclosure = itemEnclosureURL, !itemTitle.isEmpty {
                    let episode = PodcastEpisode(
                        guid: itemGuid.isEmpty ? enclosure : itemGuid,
                        title: itemTitle,
                        showTitle: feed.title,
                        feedURL: feedURL,
                        episodeDescription: itemDescription.isEmpty ? nil : stripHTML(itemDescription),
                        pubDate: itemPubDate,
                        duration: itemDuration,
                        enclosureURL: enclosure,
                        fileSize: itemEnclosureLength
                    )
                    feed.episodes.append(episode)
                }
            default:
                break
            }
        } else {
            switch elementName {
            case "title":
                if feed.title.isEmpty { feed.title = text }
            case "itunes:author":
                if feed.author == nil { feed.author = text }
            case "description":
                if feed.description == nil, !text.isEmpty { feed.description = stripHTML(text) }
            default:
                break
            }
        }
        currentText = ""
    }

    private func stripHTML(_ string: String) -> String {
        string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Retention

/// Pure retention logic: given episodes of one show currently on the device
/// (sorted or unsorted) and a keep-latest count, returns which should be removed.
enum PodcastRetention {
    /// Returns the identifiers of device episodes that fall outside the
    /// `keepLatest` newest episodes (by release date; undated episodes are
    /// considered oldest).
    static func episodesToRemove<ID: Hashable>(
        deviceEpisodes: [(id: ID, releaseDate: Date?)],
        keepLatest: Int
    ) -> [ID] {
        guard keepLatest > 0, deviceEpisodes.count > keepLatest else { return [] }
        let sorted = deviceEpisodes.sorted { a, b in
            let da = a.releaseDate ?? Date.distantPast
            let db = b.releaseDate ?? Date.distantPast
            return da > db
        }
        return sorted.dropFirst(keepLatest).map { $0.id }
    }
}
