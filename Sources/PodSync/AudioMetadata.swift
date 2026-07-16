import Foundation
import AVFoundation

struct AudioMetadata {
    var title: String?
    var artist: String?
    var album: String?
    var year: String?
    var duration: TimeInterval = 0
}

class MetadataManager {
    static func readMetadata(from url: URL) async throws -> AudioMetadata {
        let asset = AVAsset(url: url)
        
        var metadata = AudioMetadata()
        
        // Duration
        if let duration = try? await asset.load(.duration) {
            metadata.duration = duration.seconds
        }
        
        // Common metadata
        let commonMetadata = try await asset.load(.commonMetadata)
        
        for item in commonMetadata {
            guard let key = item.commonKey?.rawValue else { continue }
            
            switch key {
            case AVMetadataKey.commonKeyTitle.rawValue:
                metadata.title = try? await item.load(.stringValue)
            case AVMetadataKey.commonKeyArtist.rawValue:
                metadata.artist = try? await item.load(.stringValue)
            case AVMetadataKey.commonKeyAlbumName.rawValue:
                metadata.album = try? await item.load(.stringValue)
            case AVMetadataKey.commonKeyCreationDate.rawValue:
                metadata.year = try? await item.load(.stringValue)
            default:
                break
            }
        }
        
        return metadata
    }
}
