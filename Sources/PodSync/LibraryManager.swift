import Foundation
import AVFoundation
import AppKit
import Combine

/// Manages the music library, including folder scanning, metadata extraction, and track storage.
@MainActor
class LibraryManager: ObservableObject {
    @Published var tracks: [TrackModel] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var libraryPaths: [URL] = []

    /// Audio file extensions supported by the scanner.
    nonisolated private static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "alac", "flac", "wav", "aiff", "ogg"
    ]

    // MARK: - Public Methods

    /// Presents an NSOpenPanel for the user to select a library folder, then scans it.
    func addLibraryFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Music Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if !libraryPaths.contains(url) {
            libraryPaths.append(url)
        }

        Task {
            await scanFolder(at: url)
        }
    }

    /// Adds an array of file or folder URLs to the library.
    func addFilesOrFolders(urls: [URL]) {
        for url in urls {
            Task {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        if !libraryPaths.contains(url) {
                            libraryPaths.append(url)
                        }
                        await scanFolder(at: url)
                    } else {
                        // Single file
                        let ext = url.pathExtension.lowercased()
                        if Self.supportedExtensions.contains(ext) {
                            let track = await Task.detached(priority: .userInitiated) {
                                await Self.extractMetadata(from: url)
                            }.value
                            if let track = track {
                                if !tracks.contains(where: { $0.filePath == track.filePath }) {
                                    tracks.append(track)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Recursively scans the given folder for audio files and reads their metadata.
    /// - Parameter url: The root folder URL to scan.
    func scanFolder(at url: URL) async {
        isScanning = true
        scanProgress = 0.0

        let audioFiles = await Task.detached(priority: .userInitiated) {
            Self.findAudioFiles(in: url)
        }.value

        let totalFiles = audioFiles.count
        guard totalFiles > 0 else {
            isScanning = false
            scanProgress = 1.0
            return
        }

        // Remove existing tracks from this folder before re-scanning
        let folderPath = url.standardizedFileURL.path
        tracks.removeAll { $0.filePath.standardizedFileURL.path.hasPrefix(folderPath) }

        for (index, fileURL) in audioFiles.enumerated() {
            let track = await Task.detached(priority: .userInitiated) {
                await Self.extractMetadata(from: fileURL)
            }.value

            if let track = track {
                tracks.append(track)
            }

            scanProgress = Double(index + 1) / Double(totalFiles)
        }

        isScanning = false
    }

    /// Removes a library path and all associated tracks.
    /// - Parameter url: The library folder URL to remove.
    func removeLibrary(at url: URL) {
        libraryPaths.removeAll { $0 == url }
        let folderPath = url.standardizedFileURL.path
        tracks.removeAll { $0.filePath.standardizedFileURL.path.hasPrefix(folderPath) }
    }

    // MARK: - Private Helpers

    /// Recursively finds all audio files under the given directory.
    private nonisolated static func findAudioFiles(in directory: URL) -> [URL] {
        var results: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return results
        }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                results.append(fileURL)
            }
        }

        return results
    }

    /// Extracts metadata from an audio file using AVFoundation.
    private nonisolated static func extractMetadata(from fileURL: URL) async -> TrackModel? {
        let asset = AVURLAsset(url: fileURL)

        // Load duration
        let duration: TimeInterval
        do {
            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)
        } catch {
            duration = 0
        }

        // Load metadata
        let metadataItems: [AVMetadataItem]
        do {
            metadataItems = try await asset.load(.metadata)
        } catch {
            metadataItems = []
        }

        // Extract individual fields
        var title: String?
        var artist: String?
        var album: String?
        var albumArtist: String?
        var genre: String?
        var year: Int?
        var trackNumber: Int?
        var discNumber: Int?
        var artworkData: Data?

        for item in metadataItems {
            guard let key = item.commonKey?.rawValue ?? item.key as? String else { continue }

            switch key {
            case AVMetadataKey.commonKeyTitle.rawValue, "title":
                title = try? await item.load(.stringValue)
            case AVMetadataKey.commonKeyArtist.rawValue, "artist":
                artist = try? await item.load(.stringValue)
            case AVMetadataKey.commonKeyAlbumName.rawValue, "albumName":
                album = try? await item.load(.stringValue)
            case "albumArtist":
                albumArtist = try? await item.load(.stringValue)
            case AVMetadataKey.commonKeyType.rawValue, "genre":
                genre = try? await item.load(.stringValue)
            case AVMetadataKey.commonKeyCreationDate.rawValue, "date", "year":
                if let dateString = try? await item.load(.stringValue) {
                    // Try to extract a 4-digit year
                    if let yearVal = Int(String(dateString.prefix(4))) {
                        year = yearVal
                    }
                }
            case "trackNumber":
                if let num = try? await item.load(.numberValue) {
                    trackNumber = num.intValue
                }
            case "discNumber":
                if let num = try? await item.load(.numberValue) {
                    discNumber = num.intValue
                }
            case AVMetadataKey.commonKeyArtwork.rawValue, "artwork":
                artworkData = try? await item.load(.dataValue)
            default:
                break
            }
        }

        // File attributes
        let fileSize: Int64
        let fileFormat = fileURL.pathExtension.lowercased()

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = (attributes[.size] as? Int64) ?? 0
        } catch {
            fileSize = 0
        }

        // Use filename (without extension) as fallback title
        if title == nil {
            title = fileURL.deletingPathExtension().lastPathComponent
        }

        return TrackModel(
            filePath: fileURL,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber,
            duration: duration.isNaN ? 0 : duration,
            fileSize: fileSize,
            fileFormat: fileFormat,
            dateAdded: Date(),
            artworkData: artworkData
        )
    }
}
