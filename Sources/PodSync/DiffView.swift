import SwiftUI

/// Side-by-side diff of the Mac library vs the iPod:
/// what's on the Mac but not the iPod (syncable), and vice versa.
struct DiffView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var deviceManager: DeviceManager

    @AppStorage(PodSyncSettings.conversionFormatKey) private var conversionFormatRaw: String = ConversionFormat.aac.rawValue
    @AppStorage(PodSyncSettings.conversionBitrateKey) private var conversionBitrateRaw: Int = AudioBitrate.kbps256.rawValue

    @State private var isSyncing = false
    @State private var syncProgress = 0
    @State private var syncTotal = 0
    @State private var statusMessage: String? = nil

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    private var deviceKeys: Set<String> {
        Set(ipodManager.deviceTracks.map {
            DuplicateFinder.trackKey(title: $0.displayTitle, artist: $0.displayArtist)
        })
    }

    private var libraryKeys: Set<String> {
        Set(libraryManager.tracks.map {
            DuplicateFinder.trackKey(title: $0.displayTitle, artist: $0.displayArtist)
        })
    }

    private var onMacOnly: [TrackModel] {
        let keys = deviceKeys
        return libraryManager.tracks
            .filter { !keys.contains(DuplicateFinder.trackKey(title: $0.displayTitle, artist: $0.displayArtist)) }
            .sorted { $0.displayArtist.localizedCaseInsensitiveCompare($1.displayArtist) == .orderedAscending }
    }

    private var onIPodOnly: [TrackModel] {
        let keys = libraryKeys
        return ipodManager.deviceTracks
            .filter {
                let mt = $0.ipodMediaType ?? 1
                return (mt == 1 || mt == 0) &&
                    !keys.contains(DuplicateFinder.trackKey(title: $0.displayTitle, artist: $0.displayArtist))
            }
            .sorted { $0.displayArtist.localizedCaseInsensitiveCompare($1.displayArtist) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 26))
                Text("Library ↔ iPod")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                if let mount = ipodManager.mountpoint, Rockbox.isInstalled(mountpoint: mount) {
                    Button {
                        copyMissingToRockbox(mountpoint: mount)
                    } label: {
                        Label("Copy as Files (Rockbox)", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(onMacOnly.isEmpty || isSyncing)
                    .help("Copies the missing tracks unconverted into the Music folder for Rockbox playback")
                }
                Button {
                    syncAllMissing()
                } label: {
                    Label("Sync \(onMacOnly.count) Missing to iPod", systemImage: "ipod")
                }
                .buttonStyle(.borderedProminent)
                .disabled(deviceManager.connectedIPod == nil || onMacOnly.isEmpty || isSyncing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if deviceManager.connectedIPod == nil {
                emptyState(icon: "ipod", text: "Connect an iPod to compare it with your library.")
            } else if libraryManager.tracks.isEmpty {
                emptyState(icon: "folder", text: "Add a music folder to your library first (File → Add Folder to Library).")
            } else {
                HSplitView {
                    diffColumn(
                        title: "On Mac, not on iPod",
                        count: onMacOnly.count,
                        color: .blue,
                        tracks: onMacOnly,
                        showSyncButton: true
                    )
                    diffColumn(
                        title: "On iPod, not in library",
                        count: onIPodOnly.count,
                        color: .orange,
                        tracks: onIPodOnly,
                        showSyncButton: false
                    )
                }
            }
        }
        .overlay {
            if isSyncing {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        ProgressView(value: Double(syncProgress), total: Double(max(1, syncTotal)))
                            .frame(width: 220)
                        Text("Syncing... (\(syncProgress) / \(syncTotal))").bold()
                    }
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                }
                .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottom) {
            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 12)
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        statusMessage = nil
                    }
            }
        }
    }

    @ViewBuilder
    private func diffColumn(title: String, count: Int, color: Color, tracks: [TrackModel], showSyncButton: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)

            Divider()

            if tracks.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("Nothing here — in sync.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(tracks) { track in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(track.displayTitle).fontWeight(.medium).lineLimit(1)
                            Text("\(track.displayArtist) — \(track.displayAlbum)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if showSyncButton {
                            Button {
                                syncTracks([track])
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy to iPod")
                            .disabled(isSyncing)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyMissingToRockbox(mountpoint: String) {
        let tracks = onMacOnly.map { (source: $0.filePath, artist: $0.displayArtist, album: $0.displayAlbum, title: $0.displayTitle) }
        isSyncing = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Rockbox.copyFiles(tracks: tracks, mountpoint: mountpoint)
            }.value
            isSyncing = false
            statusMessage = "Rockbox: copied \(result.copied) files" + (result.skipped > 0 ? ", \(result.skipped) skipped" : "")
        }
    }

    // MARK: Syncing

    private func syncAllMissing() {
        syncTracks(onMacOnly)
    }

    private func syncTracks(_ tracks: [TrackModel]) {
        guard !tracks.isEmpty else { return }
        isSyncing = true
        syncProgress = 0
        syncTotal = tracks.count
        let format = ConversionFormat(rawValue: conversionFormatRaw) ?? .aac
        let bitrate = AudioBitrate(rawValue: conversionBitrateRaw) ?? .kbps256

        Task { @MainActor in
            var added = 0
            var failed = 0
            for track in tracks {
                var fileURL = track.filePath
                if AudioConverter.needsConversion(url: fileURL) {
                    do {
                        fileURL = try await AudioConverter.shared.convert(inputURL: fileURL, format: format, bitrate: bitrate)
                    } catch {
                        failed += 1
                        syncProgress += 1
                        continue
                    }
                }
                var artwork = track.artworkData
                if let data = artwork {
                    artwork = ArtworkResizer.resizeToSetting(data)
                    ArtworkCache.shared.storeToDisk(data: artwork, album: track.album)
                }
                let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? track.fileSize
                let ok = ipodManager.addTrack(
                    filePath: fileURL.path,
                    title: track.displayTitle,
                    artist: track.displayArtist,
                    album: track.displayAlbum,
                    artworkData: artwork,
                    duration: track.duration,
                    size: size,
                    year: track.year,
                    trackNum: track.trackNumber,
                    discNum: track.discNumber,
                    genre: track.genre
                )
                if ok { added += 1 } else { failed += 1 }
                syncProgress += 1
            }
            ipodManager.save()
            isSyncing = false
            statusMessage = "Synced \(added) tracks" + (failed > 0 ? ", \(failed) failed" : "")
        }
    }
}
