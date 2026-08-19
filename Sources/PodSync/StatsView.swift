import SwiftUI

/// Listening statistics computed from the iPod's own play counts and ratings.
struct StatsView: View {
    @EnvironmentObject var deviceManager: DeviceManager

    private var tracks: [TrackModel] {
        deviceManager.ipodManager.deviceTracks.filter {
            let mt = $0.ipodMediaType ?? 1
            return mt == 1 || mt == 0
        }
    }

    private var totalPlays: Int { tracks.reduce(0) { $0 + $1.playCount } }

    private var totalListeningTime: TimeInterval {
        tracks.reduce(0) { $0 + Double($1.playCount) * $1.duration }
    }

    private struct RankedItem: Identifiable {
        let id = UUID()
        let label: String
        let sublabel: String
        let plays: Int
    }

    private var topSongs: [RankedItem] {
        tracks.filter { $0.playCount > 0 }
            .sorted { $0.playCount > $1.playCount }
            .prefix(10)
            .map { RankedItem(label: $0.displayTitle, sublabel: $0.displayArtist, plays: $0.playCount) }
    }

    private var topArtists: [RankedItem] {
        Dictionary(grouping: tracks, by: { $0.displayArtist })
            .map { (artist, ts) in RankedItem(label: artist, sublabel: "\(ts.count) tracks", plays: ts.reduce(0) { $0 + $1.playCount }) }
            .filter { $0.plays > 0 }
            .sorted { $0.plays > $1.plays }
            .prefix(10)
            .map { $0 }
    }

    private var topGenres: [RankedItem] {
        Dictionary(grouping: tracks.filter { ($0.genre ?? "").isEmpty == false }, by: { $0.genre! })
            .map { (genre, ts) in RankedItem(label: genre, sublabel: "\(ts.count) tracks", plays: ts.reduce(0) { $0 + $1.playCount }) }
            .filter { $0.plays > 0 }
            .sorted { $0.plays > $1.plays }
            .prefix(6)
            .map { $0 }
    }

    private func formatListeningTime(_ t: TimeInterval) -> String {
        let hours = Int(t) / 3600
        if hours >= 24 {
            return "\(hours / 24)d \(hours % 24)h"
        }
        return "\(hours)h \((Int(t) % 3600) / 60)m"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 26))
                Text("Listening Stats")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Text("From your iPod's play counts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if deviceManager.connectedIPod == nil {
                VStack(spacing: 12) {
                    Image(systemName: "ipod")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Connect an iPod to see your stats.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if totalPlays == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No plays recorded yet")
                        .font(.title3)
                    Text("Listen to some music on the iPod, then reconnect — play counts sync back automatically.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Headline numbers
                        HStack(spacing: 16) {
                            statCard(value: "\(totalPlays)", label: "total plays", icon: "play.circle.fill", color: .blue)
                            statCard(value: formatListeningTime(totalListeningTime), label: "listening time", icon: "clock.fill", color: .purple)
                            statCard(value: "\(tracks.count)", label: "songs on iPod", icon: "music.note", color: .green)
                            statCard(value: "\(tracks.filter { $0.starRating > 0 }.count)", label: "rated songs", icon: "star.fill", color: .yellow)
                        }

                        rankedSection(title: "Top Songs", items: topSongs, color: .blue)
                        rankedSection(title: "Top Artists", items: topArtists, color: .purple)
                        if !topGenres.isEmpty {
                            rankedSection(title: "Top Genres", items: topGenres, color: .pink)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func rankedSection(title: String, items: [RankedItem], color: Color) -> some View {
        let maxPlays = items.first?.plays ?? 1
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.label).fontWeight(.medium).lineLimit(1)
                            Text(item.sublabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.plays) plays")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.opacity(0.75))
                                .frame(width: max(4, geo.size.width * CGFloat(item.plays) / CGFloat(max(1, maxPlays))))
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}
