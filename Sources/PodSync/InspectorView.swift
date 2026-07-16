import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Binding var selectedTracks: Set<TrackModel.ID>

    private var selectedTrackModels: [TrackModel] {
        libraryManager.tracks.filter { selectedTracks.contains($0.id) }
    }

    private var singleTrack: TrackModel? {
        selectedTrackModels.count == 1 ? selectedTrackModels.first : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerSection

                Divider()
                    .padding(.vertical, 8)

                // Metadata form
                if selectedTrackModels.isEmpty {
                    emptyState
                } else {
                    metadataForm
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Artwork
            artworkView
                .frame(width: 200, height: 200)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            if let track = singleTrack {
                Text(track.title ?? "Unknown Title")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(track.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("\(selectedTrackModels.count) Tracks Selected")
                    .font(.headline)
                Text("Edit shared metadata")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artworkView: some View {
        if let track = singleTrack,
           let artworkData = track.artworkData,
           let nsImage = NSImage(data: artworkData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(NSColor.systemGray).opacity(0.3),
                                Color(NSColor.systemGray).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Metadata Form

    @ViewBuilder
    private var metadataForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section {
                inspectorField(label: "Title", value: singleTrack?.title ?? "")
                inspectorField(label: "Artist", value: singleTrack?.artist ?? "")
                inspectorField(label: "Album", value: singleTrack?.album ?? "")
                inspectorField(label: "Album Artist", value: singleTrack?.albumArtist ?? "")
            } header: {
                Text("Track Info")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            Divider()

            Section {
                inspectorField(label: "Genre", value: singleTrack?.genre ?? "")
                inspectorField(label: "Year", value: singleTrack?.year.map { String($0) } ?? "")
                inspectorField(label: "Track #", value: singleTrack?.trackNumber.map { String($0) } ?? "")
                inspectorField(label: "Disc #", value: singleTrack?.discNumber.map { String($0) } ?? "")
            } header: {
                Text("Details")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            if let track = singleTrack {
                Divider()

                Section {
                    detailRow(label: "Format", value: track.fileFormat.uppercased())
                    detailRow(label: "Duration", value: track.durationFormatted)
                    detailRow(label: "Size", value: track.fileSizeFormatted)
                    detailRow(label: "Added", value: track.dateAdded.formatted(date: .abbreviated, time: .omitted))
                } header: {
                    Text("File Info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.title)
                .foregroundColor(.secondary)
            Text("Select a track to see details")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func inspectorField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField(label, text: .constant(value))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}
