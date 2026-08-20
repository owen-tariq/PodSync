import SwiftUI
import AVFoundation

/// Shows tracks that were deleted from the iPod and are still recoverable.
/// Restore re-adds a track to the library; Empty Trash frees the space.
struct TrashSheet: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [IPodManager.TrashItem] = []
    @State private var isWorking = false
    @State private var message: String? = nil

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "trash")
                    .font(.title3)
                Text("iPod Trash")
                    .font(.headline)
                Spacer()
                Text(items.isEmpty ? "Empty" : "\(items.count) items · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)

            Divider()

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Trash is empty")
                        .foregroundColor(.secondary)
                    Text("Deleted tracks are kept here until you empty the trash, so mistakes are recoverable.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).fontWeight(.medium).lineLimit(1)
                            Text("\(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)) · deleted \(item.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Restore") {
                            restore(item)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isWorking)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                if let message = message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                Button(role: .destructive) {
                    let freed = ipodManager.emptyTrash()
                    message = "Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))"
                    items = ipodManager.trashItems()
                } label: {
                    Text("Empty Trash")
                }
                .disabled(items.isEmpty || isWorking)
            }
            .padding(12)
        }
        .frame(width: 560, height: 420)
        .onAppear { items = ipodManager.trashItems() }
    }

    /// Re-add a trashed file to the iPod library, then remove it from the trash.
    private func restore(_ item: IPodManager.TrashItem) {
        isWorking = true
        Task { @MainActor in
            // Pull what metadata we can from the file itself
            let asset = AVAsset(url: item.url)
            var title = item.name
            var artist = "Unknown Artist"
            var album = "Unknown Album"

            // The trash filename is "Artist - Title"
            let guess = FilenameTagParser.parse(filename: item.url.lastPathComponent)
            if let t = guess.title { title = t }
            if let a = guess.artist { artist = a }

            let duration = CMTimeGetSeconds(asset.duration)
            let size = (try? FileManager.default.attributesOfItem(atPath: item.url.path)[.size] as? Int64) ?? 0
            let artworkImage = ArtworkCache.extractArtwork(from: item.url)
            let artworkData = artworkImage?.tiffRepresentation.flatMap {
                NSBitmapImageRep(data: $0)?.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
            }

            let ok = ipodManager.addTrack(
                filePath: item.url.path,
                title: title,
                artist: artist,
                album: album,
                artworkData: artworkData,
                duration: duration.isNaN ? 0 : duration,
                size: size,
                year: nil,
                trackNum: guess.trackNumber,
                discNum: nil
            )
            if ok {
                ipodManager.save()
                try? FileManager.default.removeItem(at: item.url)
                message = "Restored \(title)"
            } else {
                message = "Could not restore \(title)"
            }
            items = ipodManager.trashItems()
            isWorking = false
        }
    }
}
