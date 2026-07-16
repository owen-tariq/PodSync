import Foundation
import AVFoundation

enum AudioBitrate: Int, CaseIterable, Identifiable {
    case kbps320 = 320000
    case kbps256 = 256000
    case kbps128 = 128000
    
    var id: Int { rawValue }
    
    var title: String {
        "\(rawValue / 1000) kbps"
    }
}

final class AudioConverter: Sendable {
    static let shared = AudioConverter()
    
    private init() {}
    
    /// Converts an audio file to AAC (.m4a) using macOS native afconvert
    func convertToAAC(inputURL: URL, bitrate: AudioBitrate) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent).appendingPathExtension("m4a")
        
        // Remove if exists to avoid afconvert failing or appending
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
            process.arguments = [
                "-d", "aac",
                "-b", "\(bitrate.rawValue)",
                inputURL.path,
                outputURL.path
            ]
            
            do {
                try process.run()
                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: outputURL)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "AudioConverterError",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "Failed to convert file: \(inputURL.lastPathComponent)")]
                        ))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
