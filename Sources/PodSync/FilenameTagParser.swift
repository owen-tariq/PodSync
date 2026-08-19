import Foundation

/// Guesses title / artist / track number from a filename when a file has no
/// usable embedded tags. Applied automatically during sync.
///
/// Recognized patterns (extension already stripped):
///   "01 - Artist - Title"
///   "Artist - Title"
///   "01. Title" / "01 Title" / "01-Title"
///   "Title"
enum FilenameTagParser {

    struct Guess: Equatable {
        var title: String?
        var artist: String?
        var trackNumber: Int?
    }

    nonisolated static func parse(filename: String) -> Guess {
        // Strip extension and normalize separators
        var name = (filename as NSString).deletingPathExtension
        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return Guess() }

        var trackNumber: Int? = nil

        // Leading track number: "01 - ", "01. ", "01 ", "01-"
        if let match = name.range(of: #"^\d{1,3}(\s*[-.]\s*|\s+)"#, options: .regularExpression) {
            let digits = name[match].prefix(while: { $0.isNumber })
            if let n = Int(digits), n > 0, n < 500 {
                trackNumber = n
                name = String(name[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // "Artist - Title" (single separator) or "Artist - Album - Title" (take outer parts)
        let parts = name.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        switch parts.count {
        case 2:
            return Guess(title: parts[1], artist: parts[0], trackNumber: trackNumber)
        case 3...:
            return Guess(title: parts.last, artist: parts.first, trackNumber: trackNumber)
        default:
            return Guess(title: name.isEmpty ? nil : name, artist: nil, trackNumber: trackNumber)
        }
    }
}
