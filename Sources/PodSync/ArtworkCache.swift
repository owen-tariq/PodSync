import Foundation
import AVFoundation
import AppKit

/// Caches album artwork extracted from audio files on the iPod.
/// Loads artwork lazily per album name from the first available track file.
@MainActor
class ArtworkCache: ObservableObject {
    static let shared = ArtworkCache()
    
    @Published var cache: [String: NSImage] = [:]
    private var loading: Set<String> = []
    
    /// Get cached artwork for an album, or start loading it from the first track's file.
    func artwork(for albumName: String, from tracks: [TrackModel]) -> NSImage? {
        if let cached = cache[albumName] {
            return cached
        }
        
        // Don't double-load
        guard !loading.contains(albumName) else { return nil }
        loading.insert(albumName)
        
        // Find the first track that has a real file on disk
        guard let track = tracks.first(where: { FileManager.default.fileExists(atPath: $0.filePath.path) }) else {
            loading.remove(albumName)
            return nil
        }
        
        let url = track.filePath
        
        // Load artwork in background
        Task.detached(priority: .utility) {
            let image = Self.extractArtwork(from: url)
            await MainActor.run {
                if let image = image {
                    self.cache[albumName] = image
                }
                self.loading.remove(albumName)
            }
        }
        
        return nil
    }
    
    /// Extract embedded artwork from an audio file using AVFoundation.
    nonisolated static func extractArtwork(from url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let metadata = asset.commonMetadata
        
        let artworkItems = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common)
        
        guard let artworkItem = artworkItems.first else { return nil }
        
        // Try to get Data from the artwork item
        if let data = artworkItem.dataValue {
            return NSImage(data: data)
        }
        
        // Fallback: some formats store artwork as value
        if let value = artworkItem.value {
            if let data = value as? Data {
                return NSImage(data: data)
            }
        }
        
        return nil
    }
}
