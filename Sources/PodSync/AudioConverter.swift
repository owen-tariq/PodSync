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

/// Output formats for conversion. AAC uses macOS's native `afconvert`;
/// MP3 requires ffmpeg (macOS has no built-in MP3 encoder).
enum ConversionFormat: String, CaseIterable, Identifiable {
    case aac
    case mp3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aac: return "AAC (.m4a) — recommended"
        case .mp3: return "MP3 (requires ffmpeg)"
        }
    }

    var fileExtension: String {
        switch self {
        case .aac: return "m4a"
        case .mp3: return "mp3"
        }
    }
}

enum ConversionError: LocalizedError {
    case toolFailed(tool: String, file: String, detail: String)
    case ffmpegNotFound(neededFor: String)
    case unsupportedInput(ext: String)

    var errorDescription: String? {
        switch self {
        case .toolFailed(let tool, let file, let detail):
            return "\(tool) failed converting \(file): \(detail)"
        case .ffmpegNotFound(let neededFor):
            return "Converting \(neededFor) requires ffmpeg. Install it with: brew install ffmpeg"
        case .unsupportedInput(let ext):
            return ".\(ext) files are not supported for conversion."
        }
    }
}

final class AudioConverter: Sendable {
    static let shared = AudioConverter()

    private init() {}

    /// File extensions the iPod can play natively — no conversion needed.
    static let nativeExtensions: Set<String> = ["mp3", "m4a", "m4b", "m4p", "aa", "aax", "aif", "aiff", "wav"]

    /// File extensions afconvert (CoreAudio) can decode.
    static let afconvertInputs: Set<String> = ["flac", "wav", "aif", "aiff", "caf", "m4a", "mp3", "alac"]

    /// File extensions that need ffmpeg to decode.
    static let ffmpegOnlyInputs: Set<String> = ["ogg", "oga", "opus", "wma", "ape", "wv", "mpc"]

    /// All extensions we can convert (one way or another).
    static let convertibleExtensions: Set<String> = afconvertInputs.union(ffmpegOnlyInputs)

    /// Whether this file needs conversion before syncing to an iPod.
    static func needsConversion(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        // WAV/AIFF are technically native but enormous; we still sync them as-is.
        return !nativeExtensions.contains(ext) && convertibleExtensions.contains(ext)
    }

    /// Locate an ffmpeg binary if one is installed.
    static func findFFmpeg() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Convert any supported input file to the requested format/bitrate.
    /// AAC output uses afconvert for CoreAudio-supported inputs, ffmpeg otherwise.
    /// MP3 output always uses ffmpeg.
    func convert(inputURL: URL, format: ConversionFormat, bitrate: AudioBitrate) async throws -> URL {
        let ext = inputURL.pathExtension.lowercased()
        guard Self.convertibleExtensions.contains(ext) else {
            throw ConversionError.unsupportedInput(ext: ext)
        }

        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(format.fileExtension)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let needsFFmpeg = format == .mp3 || Self.ffmpegOnlyInputs.contains(ext)

        if needsFFmpeg {
            guard let ffmpeg = Self.findFFmpeg() else {
                throw ConversionError.ffmpegNotFound(
                    neededFor: format == .mp3 ? "to MP3" : ".\(ext) files"
                )
            }
            let codecArgs: [String]
            switch format {
            case .mp3: codecArgs = ["-c:a", "libmp3lame", "-b:a", "\(bitrate.rawValue / 1000)k"]
            case .aac: codecArgs = ["-c:a", "aac_at", "-b:a", "\(bitrate.rawValue / 1000)k"]
            }
            try await runProcess(
                executable: ffmpeg,
                arguments: ["-y", "-i", inputURL.path, "-vn"] + codecArgs + [outputURL.path],
                toolName: "ffmpeg",
                inputFile: inputURL.lastPathComponent
            )
        } else {
            try await runProcess(
                executable: "/usr/bin/afconvert",
                arguments: ["-d", "aac", "-b", "\(bitrate.rawValue)", "-f", "m4af", inputURL.path, outputURL.path],
                toolName: "afconvert",
                inputFile: inputURL.lastPathComponent
            )
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw ConversionError.toolFailed(
                tool: needsFFmpeg ? "ffmpeg" : "afconvert",
                file: inputURL.lastPathComponent,
                detail: "no output file was produced"
            )
        }
        return outputURL
    }

    /// Backwards-compatible entry point: convert to AAC (.m4a).
    func convertToAAC(inputURL: URL, bitrate: AudioBitrate) async throws -> URL {
        try await convert(inputURL: inputURL, format: .aac, bitrate: bitrate)
    }

    private func runProcess(executable: String, arguments: [String], toolName: String, inputFile: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe()

            do {
                try process.run()
                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errText = String(data: errData, encoding: .utf8)?
                            .split(separator: "\n")
                            .suffix(3)
                            .joined(separator: " ") ?? "exit code \(process.terminationStatus)"
                        continuation.resume(throwing: ConversionError.toolFailed(
                            tool: toolName,
                            file: inputFile,
                            detail: errText
                        ))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
