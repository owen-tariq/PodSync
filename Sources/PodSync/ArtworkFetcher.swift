import Foundation

/// Looks up missing album artwork via the iTunes Search API.
enum ArtworkFetcher {

    /// Fetch cover art for an artist/album pair. Returns JPEG/PNG data or nil.
    static func fetchArtwork(artist: String, album: String) async -> Data? {
        let term = "\(artist) \(album)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return nil }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components.url else { return nil }

        struct Response: Codable {
            struct Item: Codable {
                var collectionName: String?
                var artistName: String?
                var artworkUrl100: String?
            }
            var results: [Item]
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(Response.self, from: data)

            // Prefer an exact-ish album match, else take the first result
            let best = decoded.results.first { item in
                item.collectionName?.localizedCaseInsensitiveContains(album) == true
            } ?? decoded.results.first

            guard var artURLString = best?.artworkUrl100 else { return nil }
            // Upgrade to 600x600
            artURLString = artURLString.replacingOccurrences(of: "100x100", with: "600x600")
            guard let artURL = URL(string: artURLString) else { return nil }
            let (artData, _) = try await URLSession.shared.data(from: artURL)
            return artData
        } catch {
            print("[ArtworkFetcher] Lookup failed: \(error.localizedDescription)")
            return nil
        }
    }
}
