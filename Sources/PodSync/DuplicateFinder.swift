import SwiftUI

/// Finds duplicate tracks on the device (same normalized title + artist).
enum DuplicateFinder {

    struct Group: Identifiable {
        let id = UUID()
        let key: String
        let tracks: [TrackModel]
    }

    /// Normalization used for duplicate matching and library/iPod diffing.
    nonisolated static func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    nonisolated static func trackKey(title: String, artist: String) -> String {
        normalize(title) + "|" + normalize(artist)
    }

    /// Group music tracks that appear more than once.
    nonisolated static func findDuplicates(in tracks: [TrackModel]) -> [Group] {
        let music = tracks.filter {
            let mt = $0.ipodMediaType ?? 1
            return mt == 1 || mt == 0
        }
        let grouped = Dictionary(grouping: music) {
            trackKey(title: $0.displayTitle, artist: $0.displayArtist)
        }
        return grouped
            .filter { $0.value.count > 1 }
            .map { Group(key: $0.key, tracks: $0.value.sorted { betterCopy($0, than: $1) }) }
            .sorted { $0.tracks.first!.displayTitle.localizedCaseInsensitiveCompare($1.tracks.first!.displayTitle) == .orderedAscending }
    }

    /// True when a is the better copy to KEEP (higher bitrate, then bigger file, then more plays).
    nonisolated static func betterCopy(_ a: TrackModel, than b: TrackModel) -> Bool {
        if a.bitrate != b.bitrate { return a.bitrate > b.bitrate }
        if a.fileSize != b.fileSize { return a.fileSize > b.fileSize }
        return a.playCount > b.playCount
    }

    /// Everything except the best copy in each group.
    nonisolated static func suggestedDeletions(in groups: [Group]) -> Set<UUID> {
        var result = Set<UUID>()
        for group in groups {
            for track in group.tracks.dropFirst() {
                result.insert(track.id)
            }
        }
        return result
    }
}

// MARK: - Sheet

struct DuplicateFinderSheet: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss

    @State private var groups: [DuplicateFinder.Group] = []
    @State private var selected = Set<UUID>()
    @State private var scanned = false
    @State private var isDeleting = false

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.on.doc")
                    .font(.title3)
                Text("Duplicate Finder")
                    .font(.headline)
                Spacer()
                if scanned {
                    Text(groups.isEmpty ? "No duplicates found" : "\(groups.count) duplicated songs · \(selected.count) selected for deletion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)

            Divider()

            if !scanned {
                VStack { ProgressView(); Text("Scanning...").font(.caption).foregroundColor(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                    Text("Your iPod has no duplicate songs.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groups) { group in
                        Section(group.tracks.first!.displayTitle + " — " + group.tracks.first!.displayArtist) {
                            ForEach(group.tracks) { track in
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { selected.contains(track.id) },
                                        set: { on in
                                            if on { selected.insert(track.id) } else { selected.remove(track.id) }
                                        }
                                    ))
                                    .labelsHidden()

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(track.displayAlbum)
                                        Text("\(track.bitrate > 0 ? "\(track.bitrate) kbps · " : "")\(track.fileSizeFormatted) · \(track.playCount) plays")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if !selected.contains(track.id) {
                                        Text("KEEP")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Text("Checked tracks will be deleted; the best copy (highest bitrate) is kept by default.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                Button(role: .destructive) {
                    isDeleting = true
                    let ids = selected
                    Task { @MainActor in
                        _ = ipodManager.deleteTracks(ids: ids)
                        isDeleting = false
                        dismiss()
                    }
                } label: {
                    if isDeleting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Delete \(selected.count) Duplicates")
                    }
                }
                .disabled(selected.isEmpty || isDeleting)
            }
            .padding(12)
        }
        .frame(width: 620, height: 480)
        .task {
            let tracks = ipodManager.deviceTracks
            let found = await Task.detached(priority: .userInitiated) {
                DuplicateFinder.findDuplicates(in: tracks)
            }.value
            groups = found
            selected = DuplicateFinder.suggestedDeletions(in: found)
            scanned = true
        }
    }
}
