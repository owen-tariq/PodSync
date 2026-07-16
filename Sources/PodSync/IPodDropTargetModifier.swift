import SwiftUI
import AVFoundation

struct IPodDropTargetModifier: ViewModifier {
    @EnvironmentObject var deviceManager: DeviceManager
    
    var ipodManager: IPodManager {
        deviceManager.ipodManager
    }
    
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    guard let data = item as? Data,
                          let urlString = String(data: data, encoding: .utf8),
                          let url = URL(string: urlString) else { return }
                    
                    Task { @MainActor in
                        addFilesToIPod(url: url)
                    }
                }
            }
        }
        return true
    }
    
    @MainActor
    private func addFilesToIPod(url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            // It's a directory, enumerate its contents
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { return }
            for case let fileURL as URL in enumerator {
                if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegularFile {
                    if fileURL.pathExtension.lowercased() == "mp3" || fileURL.pathExtension.lowercased() == "m4a" {
                        addSingleFileToIPod(url: fileURL)
                    }
                }
            }
        } else {
            // It's a single file
            addSingleFileToIPod(url: url)
        }
        ipodManager.save()
    }
    
    @MainActor
    private func addSingleFileToIPod(url: URL) {
        let asset = AVAsset(url: url)
        
        let titleItem = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: .common).first
        let artistItem = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: .common).first
        let albumItem = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyAlbumName, keySpace: .common).first
        
        let title = titleItem?.stringValue ?? url.deletingPathExtension().lastPathComponent
        let artist = artistItem?.stringValue ?? "Unknown Artist"
        let album = albumItem?.stringValue ?? "Unknown Album"
        
        let success = ipodManager.addTrack(
            filePath: url.path,
            title: title,
            artist: artist,
            album: album,
            artworkData: nil,
            duration: CMTimeGetSeconds(asset.duration),
            size: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
            year: nil,
            trackNum: nil,
            discNum: nil
        )
        
        if success {
            print("Successfully added: \(title)")
        }
    }
}

extension View {
    func ipodDropTarget() -> some View {
        self.modifier(IPodDropTargetModifier())
    }
}
