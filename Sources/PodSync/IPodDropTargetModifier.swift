import SwiftUI
import AVFoundation
import QuickLookThumbnailing
import CoreServices

/// What will happen when a dropped set of files is synced.
struct SyncPlan {
    struct Item: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
        let artist: String
        let album: String
        let duration: Double
        var reason: String = ""
    }

    var adds: [Item] = []        // native formats, copied as-is
    var converts: [Item] = []    // need conversion first
    var duplicates: [Item] = []  // already on device — skipped
    var unsupported: [Item] = [] // cannot be converted

    var isEmpty: Bool { adds.isEmpty && converts.isEmpty && duplicates.isEmpty && unsupported.isEmpty }
    var totalToSync: Int { adds.count + converts.count }
}

struct IPodDropTargetModifier: ViewModifier {
    @EnvironmentObject var deviceManager: DeviceManager

    @AppStorage(PodSyncSettings.syncPlanEnabledKey) private var syncPlanEnabled: Bool = true
    @AppStorage(PodSyncSettings.conversionFormatKey) private var conversionFormatRaw: String = ConversionFormat.aac.rawValue
    @AppStorage(PodSyncSettings.conversionBitrateKey) private var conversionBitrateRaw: Int = AudioBitrate.kbps256.rawValue

    @State private var plan: SyncPlan? = nil
    @State private var showPlanSheet = false
    @State private var isSyncing = false
    @State private var syncProgress = 0
    @State private var syncTotal = 0
    @State private var syncErrors: [String] = []
    @State private var showErrors = false

    var ipodManager: IPodManager {
        deviceManager.ipodManager
    }

    private var conversionFormat: ConversionFormat {
        ConversionFormat(rawValue: conversionFormatRaw) ?? .aac
    }

    private var conversionBitrate: AudioBitrate {
        AudioBitrate(rawValue: conversionBitrateRaw) ?? .kbps256
    }

    /// Extensions synced without conversion.
    static let nativeExtensions: Set<String> = ["mp3", "m4a", "m4b", "m4p", "mp4", "m4v", "mov", "wav", "aif", "aiff"]

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            .sheet(isPresented: $showPlanSheet) {
                if let plan = plan {
                    SyncPlanSheet(
                        plan: plan,
                        formatRaw: $conversionFormatRaw,
                        bitrateRaw: $conversionBitrateRaw,
                        onConfirm: {
                            showPlanSheet = false
                            executePlan(plan)
                        },
                        onCancel: {
                            showPlanSheet = false
                            self.plan = nil
                        }
                    )
                }
            }
            .alert("Some files failed", isPresented: $showErrors) {
                Button("OK") { syncErrors = [] }
            } message: {
                Text(syncErrors.prefix(5).joined(separator: "\n"))
            }
            .overlay {
                if isSyncing {
                    ZStack {
                        Color.black.opacity(0.5)
                        VStack(spacing: 16) {
                            ProgressView(value: Double(syncProgress), total: Double(max(1, syncTotal)))
                                .frame(width: 220)
                            Text(String(localized: "Syncing... (\(syncProgress) / \(syncTotal))"))
                                .bold()
                        }
                        .padding(24)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                    .ignoresSafeArea()
                }
            }
    }

    // MARK: - Drop handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            var collectedURLs: [URL] = []

            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                    if let url = await loadURL(from: provider) {
                        collectedURLs.append(url)
                    }
                }
            }

            await buildAndPresentPlan(collectedURLs)
        }
        return true
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                if let data = item as? Data,
                   let urlString = String(data: data, encoding: .utf8),
                   let url = URL(string: urlString) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Synchronously expand dropped folders into a flat list of audio files.
    /// (FileManager's enumerator cannot be iterated from an async context.)
    private nonisolated static func expandDroppedURLs(_ urls: [URL]) -> [URL] {
        var files: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
                for case let fileURL as URL in enumerator {
                    if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegularFile {
                        files.append(fileURL)
                    }
                }
            } else {
                files.append(url)
            }
        }
        let allAudioExts = nativeExtensions.union(AudioConverter.convertibleExtensions)
        return files.filter { allAudioExts.contains($0.pathExtension.lowercased()) }
    }

    /// Expand folders, classify every file, detect duplicates, and build the plan.
    @MainActor
    private func buildAndPresentPlan(_ urls: [URL]) async {
        let files = Self.expandDroppedURLs(urls)
        guard !files.isEmpty else { return }

        var newPlan = SyncPlan()
        let deviceTracks = ipodManager.deviceTracks

        for file in files {
            let meta = await readBasicMetadata(url: file)
            var item = SyncPlan.Item(url: file, title: meta.title, artist: meta.artist, album: meta.album, duration: meta.duration)

            // Duplicate detection: same title + artist already on device
            let isDuplicate = deviceTracks.contains { track in
                track.displayTitle.caseInsensitiveCompare(meta.title) == .orderedSame &&
                (meta.artist == "Unknown Artist" || track.displayArtist.caseInsensitiveCompare(meta.artist) == .orderedSame)
            }

            let ext = file.pathExtension.lowercased()
            if isDuplicate {
                item.reason = "Already on iPod"
                newPlan.duplicates.append(item)
            } else if Self.nativeExtensions.contains(ext) {
                newPlan.adds.append(item)
            } else if AudioConverter.convertibleExtensions.contains(ext) {
                if AudioConverter.ffmpegOnlyInputs.contains(ext) && AudioConverter.findFFmpeg() == nil {
                    item.reason = ".\(ext) needs ffmpeg (brew install ffmpeg)"
                    newPlan.unsupported.append(item)
                } else {
                    item.reason = ".\(ext) → .\(conversionFormat.fileExtension)"
                    newPlan.converts.append(item)
                }
            }
        }

        guard !newPlan.isEmpty else { return }

        if syncPlanEnabled {
            self.plan = newPlan
            self.showPlanSheet = true
        } else {
            executePlan(newPlan)
        }
    }

    // MARK: - Plan execution

    @MainActor
    private func executePlan(_ plan: SyncPlan) {
        isSyncing = true
        syncProgress = 0
        syncTotal = plan.totalToSync
        syncErrors = []

        Task { @MainActor in
            for item in plan.adds {
                await addSingleFileToIPod(url: item.url)
                syncProgress += 1
            }

            for item in plan.converts {
                do {
                    let converted = try await AudioConverter.shared.convert(
                        inputURL: item.url,
                        format: conversionFormat,
                        bitrate: conversionBitrate
                    )
                    await addSingleFileToIPod(url: converted, originalURL: item.url)
                } catch {
                    syncErrors.append(error.localizedDescription)
                }
                syncProgress += 1
            }

            ipodManager.save()
            isSyncing = false
            self.plan = nil

            if !syncErrors.isEmpty {
                showErrors = true
            }
        }
    }

    // MARK: - Metadata

    private struct BasicMetadata {
        var title: String
        var artist: String
        var album: String
        var duration: Double
        var genre: String?
        var year: Int?
        var trackNumber: Int?
    }

    private func readBasicMetadata(url: URL) async -> BasicMetadata {
        var meta = BasicMetadata(
            title: url.deletingPathExtension().lastPathComponent,
            artist: "Unknown Artist",
            album: "Unknown Album",
            duration: 0
        )

        if let mdItem = MDItemCreateWithURL(nil, url as CFURL) {
            if let titleAttr = MDItemCopyAttribute(mdItem, kMDItemTitle) as? String {
                meta.title = titleAttr
            }
            if let authorsAttr = MDItemCopyAttribute(mdItem, kMDItemAuthors) as? [String], let firstAuthor = authorsAttr.first {
                meta.artist = firstAuthor
            }
            if let albumAttr = MDItemCopyAttribute(mdItem, kMDItemAlbum) as? String {
                meta.album = albumAttr
            }
            if let durationAttr = MDItemCopyAttribute(mdItem, kMDItemDurationSeconds) as? Double {
                meta.duration = durationAttr
            }
            if let genreAttr = MDItemCopyAttribute(mdItem, kMDItemMusicalGenre) as? String {
                meta.genre = genreAttr
            }
            if let yearAttr = MDItemCopyAttribute(mdItem, kMDItemRecordingYear) as? Int {
                meta.year = yearAttr
            }
            if let trackAttr = MDItemCopyAttribute(mdItem, kMDItemAudioTrackNumber) as? Int {
                meta.trackNumber = trackAttr
            }
        }

        return meta
    }

    @MainActor
    private func addSingleFileToIPod(url: URL, originalURL: URL? = nil) async {
        let sourceURL = originalURL ?? url
        var meta = await readBasicMetadata(url: sourceURL)

        // Fallback to AVAsset for duration if MDItem didn't provide it
        if meta.duration == 0 {
            let targetAsset = AVAsset(url: url)
            let assetDuration = CMTimeGetSeconds(targetAsset.duration)
            if !assetDuration.isNaN && !assetDuration.isInfinite {
                meta.duration = assetDuration
            }
        }

        let artworkData = await getArtworkData(url: sourceURL)

        let success = ipodManager.addTrack(
            filePath: url.path,
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            artworkData: artworkData,
            duration: meta.duration,
            size: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
            year: meta.year,
            trackNum: meta.trackNumber,
            discNum: nil,
            genre: meta.genre
        )

        if success {
            print("Successfully added: \(meta.title)")
        }
    }

    private func getArtworkData(url: URL) async -> Data? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 500, height: 500), scale: 1.0, representationTypes: .thumbnail)
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let cgImage = thumbnail?.cgImage {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    if let tiff = nsImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
                        let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
                        continuation.resume(returning: jpegData)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Sync Plan Sheet

struct SyncPlanSheet: View {
    let plan: SyncPlan
    @Binding var formatRaw: String
    @Binding var bitrateRaw: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "list.clipboard")
                    .font(.title2)
                Text("Review Sync Plan")
                    .font(.headline)
                Spacer()
                Text("\(plan.totalToSync) will sync")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)

            Divider()

            List {
                if !plan.adds.isEmpty {
                    Section("ADD (\(plan.adds.count))") {
                        ForEach(plan.adds) { item in
                            planRow(item: item, icon: "plus.circle.fill", color: .green)
                        }
                    }
                }
                if !plan.converts.isEmpty {
                    Section("CONVERT & ADD (\(plan.converts.count))") {
                        ForEach(plan.converts) { item in
                            planRow(item: item, icon: "waveform.circle.fill", color: .blue)
                        }
                    }
                }
                if !plan.duplicates.isEmpty {
                    Section("SKIP — DUPLICATES (\(plan.duplicates.count))") {
                        ForEach(plan.duplicates) { item in
                            planRow(item: item, icon: "exclamationmark.circle.fill", color: .orange)
                        }
                    }
                }
                if !plan.unsupported.isEmpty {
                    Section("CANNOT SYNC (\(plan.unsupported.count))") {
                        ForEach(plan.unsupported) { item in
                            planRow(item: item, icon: "xmark.circle.fill", color: .red)
                        }
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                if !plan.converts.isEmpty {
                    Picker("", selection: $formatRaw) {
                        ForEach(ConversionFormat.allCases) { f in
                            Text(f.fileExtension.uppercased()).tag(f.rawValue)
                        }
                    }
                    .frame(width: 90)
                    Picker("", selection: $bitrateRaw) {
                        ForEach(AudioBitrate.allCases) { b in
                            Text(b.title).tag(b.rawValue)
                        }
                    }
                    .frame(width: 110)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Sync \(plan.totalToSync) Files", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(plan.totalToSync == 0)
            }
            .padding(12)
        }
        .frame(width: 560, height: 440)
    }

    @ViewBuilder
    private func planRow(item: SyncPlan.Item, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(item.artist) — \(item.url.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if !item.reason.isEmpty {
                Text(item.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

extension View {
    func ipodDropTarget() -> some View {
        self.modifier(IPodDropTargetModifier())
    }
}
