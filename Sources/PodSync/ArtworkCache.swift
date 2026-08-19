import Foundation
import AVFoundation
import AppKit

/// Resizes artwork before it is written to the iPod. Large embedded covers
/// (2000×2000+) waste space and slow the device; the iPod displays ~320px.
enum ArtworkResizer {
    /// Downscale image data so its longest side is at most `maxDimension`.
    /// Pass 0 to keep the original size. Returns JPEG data (or the original
    /// data when no resize was needed or decoding failed).
    nonisolated static func resize(_ data: Data, maxDimension: Int) -> Data {
        guard maxDimension > 0,
              let image = NSImage(data: data),
              let rep = NSBitmapImageRep(data: data) else { return data }

        let pw = rep.pixelsWide
        let ph = rep.pixelsHigh
        guard max(pw, ph) > maxDimension else { return data }

        let scale = Double(maxDimension) / Double(max(pw, ph))
        let nw = max(1, Int(Double(pw) * scale))
        let nh = max(1, Int(Double(ph) * scale))

        guard let newRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: nw,
            pixelsHigh: nh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return data }
        newRep.size = NSSize(width: nw, height: nh)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)
        image.draw(
            in: NSRect(x: 0, y: 0, width: CGFloat(nw), height: CGFloat(nh)),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        return newRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) ?? data
    }

    /// The user's configured max artwork dimension (0 = keep original).
    nonisolated static func configuredMaxDimension() -> Int {
        if UserDefaults.standard.object(forKey: PodSyncSettings.artworkMaxSizeKey) == nil {
            return 600 // sensible default
        }
        return UserDefaults.standard.integer(forKey: PodSyncSettings.artworkMaxSizeKey)
    }

    /// Resize using the user's configured setting.
    nonisolated static func resizeToSetting(_ data: Data) -> Data {
        resize(data, maxDimension: configuredMaxDimension())
    }
}

/// Caches album artwork for display inside the app.
/// Sources, in order: memory → on-disk cache (saved at sync time) → embedded
/// artwork extracted from the track file on the iPod.
@MainActor
class ArtworkCache: ObservableObject {
    static let shared = ArtworkCache()

    @Published var cache: [String: NSImage] = [:]
    private var loading: Set<String> = []

    // MARK: Disk cache

    nonisolated private static var diskDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PodSync/Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated private static func diskURL(forAlbum album: String) -> URL {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safe = album.components(separatedBy: invalid).joined(separator: "_")
        return diskDir.appendingPathComponent(safe).appendingPathExtension("jpg")
    }

    /// Save artwork for an album to the on-disk cache (called at sync/edit time),
    /// so the app can always display it even when the device file has no
    /// embedded art (e.g. after conversion).
    func storeToDisk(data: Data?, album: String?) {
        guard let data = data, let album = album, !album.isEmpty else { return }
        try? data.write(to: Self.diskURL(forAlbum: album))
        if let image = NSImage(data: data) {
            cache[album] = image
        }
    }

    /// Get cached artwork for an album, or start loading it (disk cache first,
    /// then embedded artwork from the first available track file).
    func artwork(for albumName: String, from tracks: [TrackModel]) -> NSImage? {
        if let cached = cache[albumName] {
            return cached
        }

        // Don't double-load
        guard !loading.contains(albumName) else { return nil }
        loading.insert(albumName)

        let fileURL = tracks.first(where: { FileManager.default.fileExists(atPath: $0.filePath.path) })?.filePath
        let diskURL = Self.diskURL(forAlbum: albumName)

        // Load artwork in background: disk cache first, then file extraction
        Task.detached(priority: .utility) {
            var image: NSImage? = nil
            if let data = try? Data(contentsOf: diskURL) {
                image = NSImage(data: data)
            }
            if image == nil, let fileURL = fileURL {
                image = Self.extractArtwork(from: fileURL)
            }
            let result = image
            await MainActor.run {
                if let result = result {
                    self.cache[albumName] = result
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
