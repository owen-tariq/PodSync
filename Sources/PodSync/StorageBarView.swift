import SwiftUI

/// iTunes-style colored capacity bar: music / podcasts / audiobooks / video /
/// other / free, computed from the device tracks and volume capacity.
struct StorageBarView: View {
    let device: IPodDevice
    let tracks: [TrackModel]

    private struct Segment: Identifiable {
        let id = UUID()
        let label: String
        let bytes: Int64
        let color: Color
    }

    private var segments: [Segment] {
        var music: Int64 = 0
        var podcasts: Int64 = 0
        var audiobooks: Int64 = 0
        var video: Int64 = 0

        for track in tracks {
            switch track.ipodMediaType ?? 1 {
            case 2, 32, 64: video += track.fileSize
            case 4: podcasts += track.fileSize
            case 8: audiobooks += track.fileSize
            default: music += track.fileSize
            }
        }

        let used = device.totalCapacity - device.availableCapacity
        let accounted = music + podcasts + audiobooks + video
        let other = max(0, used - accounted)
        let free = max(0, device.availableCapacity)

        return [
            Segment(label: "Music", bytes: music, color: .blue),
            Segment(label: "Podcasts", bytes: podcasts, color: .purple),
            Segment(label: "Audiobooks", bytes: audiobooks, color: .green),
            Segment(label: "Video", bytes: video, color: .pink),
            Segment(label: "Other", bytes: other, color: Color(NSColor.systemGray)),
            Segment(label: "Free", bytes: free, color: Color(NSColor.quaternaryLabelColor))
        ].filter { $0.bytes > 0 }
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        let total = max(1, device.totalCapacity)
        VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(2, geo.size.width * CGFloat(segment.bytes) / CGFloat(total)))
                            .help("\(segment.label): \(format(segment.bytes))")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(height: 14)

            HStack(spacing: 14) {
                ForEach(segments) { segment in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 8, height: 8)
                        Text("\(segment.label) \(format(segment.bytes))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: 480)
    }
}
