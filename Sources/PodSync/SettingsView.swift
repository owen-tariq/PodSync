import SwiftUI

/// App-wide preferences, persisted via @AppStorage.
enum PodSyncSettings {
    static let conversionFormatKey = "podsync.conversionFormat"
    static let conversionBitrateKey = "podsync.conversionBitrate"
    static let syncPlanEnabledKey = "podsync.syncPlanEnabled"
    static let podcastKeepLatestDefaultKey = "podsync.podcastKeepLatestDefault"
    static let podcastSyncLatestKey = "podsync.podcastSyncLatest"
}

struct SettingsView: View {
    @AppStorage(PodSyncSettings.conversionFormatKey) private var conversionFormat: String = ConversionFormat.aac.rawValue
    @AppStorage(PodSyncSettings.conversionBitrateKey) private var conversionBitrate: Int = AudioBitrate.kbps256.rawValue
    @AppStorage(PodSyncSettings.syncPlanEnabledKey) private var syncPlanEnabled: Bool = true
    @AppStorage(PodSyncSettings.podcastKeepLatestDefaultKey) private var podcastKeepLatestDefault: Int = 0
    @AppStorage(PodSyncSettings.podcastSyncLatestKey) private var podcastSyncLatest: Int = 5

    private var ffmpegInstalled: Bool { AudioConverter.findFFmpeg() != nil }

    var body: some View {
        TabView {
            conversionTab
                .tabItem { Label("Conversion", systemImage: "waveform") }
            syncTab
                .tabItem { Label("Syncing", systemImage: "arrow.triangle.2.circlepath") }
            podcastsTab
                .tabItem { Label("Podcasts", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .frame(width: 460, height: 300)
    }

    private var conversionTab: some View {
        Form {
            Picker("Output format:", selection: $conversionFormat) {
                ForEach(ConversionFormat.allCases) { format in
                    Text(format.title).tag(format.rawValue)
                }
            }
            Picker("Bitrate:", selection: $conversionBitrate) {
                ForEach(AudioBitrate.allCases) { bitrate in
                    Text(bitrate.title).tag(bitrate.rawValue)
                }
            }

            if conversionFormat == ConversionFormat.mp3.rawValue && !ffmpegInstalled {
                Label("ffmpeg not found — MP3 output won't work. Install with: brew install ffmpeg", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Text(ffmpegInstalled
                 ? "ffmpeg detected — FLAC, OGG, Opus, WMA and more can be converted."
                 : "Without ffmpeg, PodSync can still convert FLAC/WAV/AIFF to AAC using macOS's built-in encoder. Install ffmpeg for OGG/Opus/WMA support and MP3 output.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }

    private var syncTab: some View {
        Form {
            Toggle("Review sync plan before adding dropped files", isOn: $syncPlanEnabled)
            Text("When enabled, dropping files onto the iPod shows a summary of what will be added, converted, and skipped as duplicates before anything is written.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }

    private var podcastsTab: some View {
        Form {
            Picker("Sync latest episodes per show:", selection: $podcastSyncLatest) {
                ForEach([1, 3, 5, 10, 25], id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            Picker("Default retention (keep on iPod):", selection: $podcastKeepLatestDefault) {
                Text("Keep all").tag(0)
                ForEach([3, 5, 10, 25], id: \.self) { n in
                    Text("Latest \(n)").tag(n)
                }
            }
            Text("Retention removes older episodes of a show from the iPod when new ones are synced. You can override this per show.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }
}
