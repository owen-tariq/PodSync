import SwiftUI
import AVFoundation
import QuickLookThumbnailing
import CoreServices

struct IPodDropTargetModifier: ViewModifier {
    @EnvironmentObject var deviceManager: DeviceManager
    
    @State private var showingConversionPrompt = false
    @State private var flacFilesToConvert: [URL] = []
    @State private var otherFilesToSync: [URL] = []
    @State private var isConverting = false
    @State private var conversionProgress = 0
    
    var ipodManager: IPodManager {
        deviceManager.ipodManager
    }
    
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            .confirmationDialog(
                String(localized: "Convert FLAC Files"),
                isPresented: $showingConversionPrompt,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Convert to 320 kbps (High Quality)")) {
                    startConversion(bitrate: .kbps320)
                }
                Button(String(localized: "Convert to 256 kbps (Standard)")) {
                    startConversion(bitrate: .kbps256)
                }
                Button(String(localized: "Convert to 128 kbps (Smaller Size)")) {
                    startConversion(bitrate: .kbps128)
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    // Sync the non-FLAC files anyway
                    Task { @MainActor in
                        for file in otherFilesToSync {
                            await addSingleFileToIPod(url: file)
                        }
                        ipodManager.save()
                    }
                }
            } message: {
                Text(String(localized: "You dropped \(flacFilesToConvert.count) FLAC file(s). iPods do not play FLAC files natively. Would you like to convert them to AAC (.m4a) for syncing?"))
            }
            .overlay {
                if isConverting {
                    ZStack {
                        Color.black.opacity(0.5)
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text(String(localized: "Converting... (\(conversionProgress) / \(flacFilesToConvert.count))"))
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
            
            processCollectedURLs(collectedURLs)
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
    
    @MainActor
    private func processCollectedURLs(_ urls: [URL]) {
        var flacs: [URL] = []
        var others: [URL] = []
        
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
                for case let fileURL as URL in enumerator {
                    if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegularFile {
                        let ext = fileURL.pathExtension.lowercased()
                        if ext == "mp3" || ext == "m4a" {
                            others.append(fileURL)
                        } else if ext == "flac" {
                            flacs.append(fileURL)
                        }
                    }
                }
            } else {
                let ext = url.pathExtension.lowercased()
                if ext == "mp3" || ext == "m4a" {
                    others.append(url)
                } else if ext == "flac" {
                    flacs.append(url)
                }
            }
        }
        
        if !flacs.isEmpty {
            self.flacFilesToConvert = flacs
            self.otherFilesToSync = others
            self.showingConversionPrompt = true
        } else {
            Task { @MainActor in
                for file in others {
                    await addSingleFileToIPod(url: file)
                }
                ipodManager.save()
            }
        }
    }
    
    private func startConversion(bitrate: AudioBitrate) {
        isConverting = true
        conversionProgress = 0
        
        Task { @MainActor in
            for file in otherFilesToSync {
                await addSingleFileToIPod(url: file)
            }
            
            for flacURL in flacFilesToConvert {
                do {
                    let m4aURL = try await AudioConverter.shared.convertToAAC(inputURL: flacURL, bitrate: bitrate)
                    await addSingleFileToIPod(url: m4aURL, originalURL: flacURL)
                } catch {
                    print("Conversion failed for \(flacURL.lastPathComponent): \(error)")
                }
                conversionProgress += 1
            }
            
            ipodManager.save()
            isConverting = false
            flacFilesToConvert.removeAll()
            otherFilesToSync.removeAll()
        }
    }
    
    @MainActor
    private func addSingleFileToIPod(url: URL, originalURL: URL? = nil) async {
        let sourceURL = originalURL ?? url
        let targetAsset = AVAsset(url: url)
        
        var title: String = sourceURL.deletingPathExtension().lastPathComponent
        var artist: String = "Unknown Artist"
        var album: String = "Unknown Album"
        
        if let mdItem = MDItemCreateWithURL(nil, sourceURL as CFURL) {
            if let titleAttr = MDItemCopyAttribute(mdItem, kMDItemTitle) as? String {
                title = titleAttr
            }
            if let authorsAttr = MDItemCopyAttribute(mdItem, kMDItemAuthors) as? [String], let firstAuthor = authorsAttr.first {
                artist = firstAuthor
            }
            if let albumAttr = MDItemCopyAttribute(mdItem, kMDItemAlbum) as? String {
                album = albumAttr
            }
        }
        
        let artworkData = await getArtworkData(url: sourceURL)
        
        let success = ipodManager.addTrack(
            filePath: url.path,
            title: title,
            artist: artist,
            album: album,
            artworkData: artworkData,
            duration: CMTimeGetSeconds(targetAsset.duration),
            size: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
            year: nil,
            trackNum: nil,
            discNum: nil
        )
        
        if success {
            print("Successfully added: \(title)")
        }
    }
    
    private func getArtworkData(url: URL) async -> Data? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 500, height: 500), scale: 1.0, representationTypes: .thumbnail)
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let cgImage = thumbnail?.cgImage {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    if let tiff = nsImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
                        let pngData = bitmap.representation(using: .png, properties: [:])
                        continuation.resume(returning: pngData)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }
}

extension View {
    func ipodDropTarget() -> some View {
        self.modifier(IPodDropTargetModifier())
    }
}
