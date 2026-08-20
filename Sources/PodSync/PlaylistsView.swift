import SwiftUI

// MARK: - Device Playlists Overview

struct DevicePlaylistsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject private var smartStore = SmartPlaylistStore.shared

    @State private var showNewPlaylistPrompt = false
    @State private var newPlaylistName = ""
    @State private var renamingPlaylist: PlaylistModel? = nil
    @State private var renameText = ""
    @State private var editingSmartPlaylist: SmartPlaylist? = nil
    @State private var showSmartEditor = false
    @State private var applyResult: String? = nil
    @State private var selectedPlaylistId: UInt64? = nil

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    private var userPlaylists: [PlaylistModel] {
        ipodManager.devicePlaylists.filter { !$0.isMaster }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if deviceManager.connectedIPod == nil {
                emptyState(icon: "ipod", title: "No iPod Connected", message: "Connect an iPod to manage its playlists.")
            } else {
                HSplitView {
                    playlistList
                        .frame(minWidth: 260, idealWidth: 300)
                    playlistDetail
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .alert("New Playlist", isPresented: $showNewPlaylistPrompt) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
            Button("Create") {
                if !newPlaylistName.isEmpty {
                    ipodManager.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        }
        .alert("Rename Playlist", isPresented: Binding(
            get: { renamingPlaylist != nil },
            set: { if !$0 { renamingPlaylist = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingPlaylist = nil }
            Button("Rename") {
                if let pl = renamingPlaylist, !renameText.isEmpty {
                    ipodManager.renamePlaylist(id: pl.id, newName: renameText)
                }
                renamingPlaylist = nil
            }
        }
        .sheet(isPresented: $showSmartEditor) {
            SmartPlaylistEditorView(
                playlist: editingSmartPlaylist ?? SmartPlaylist(name: "New Smart Playlist"),
                isNew: editingSmartPlaylist == nil
            )
        }
        .overlay(alignment: .bottom) {
            if let result = applyResult {
                Text(result)
                    .font(.caption)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 12)
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        applyResult = nil
                    }
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28))
            Text("Playlists")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            Button {
                showNewPlaylistPrompt = true
            } label: {
                Label("New Playlist", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .disabled(deviceManager.connectedIPod == nil)

            Button {
                editingSmartPlaylist = nil
                showSmartEditor = true
            } label: {
                Label("New Smart Playlist", systemImage: "gearshape.2")
            }
            .buttonStyle(.bordered)

            Menu {
                Button {
                    applyResult = PlaylistBackup.backupViaPanel(
                        ipodManager: ipodManager,
                        deviceName: deviceManager.connectedIPod?.name ?? "iPod"
                    )
                } label: {
                    Label("Backup Playlists...", systemImage: "square.and.arrow.down")
                }
                Button {
                    applyResult = PlaylistBackup.restoreViaPanel(ipodManager: ipodManager)
                } label: {
                    Label("Restore Playlists...", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button {
                    importM3U()
                } label: {
                    Label("Import Playlist from M3U...", systemImage: "doc.badge.plus")
                }
            } label: {
                Label("Backup", systemImage: "externaldrive")
            }
            .menuStyle(.borderedButton)
            .frame(width: 110)
            .disabled(deviceManager.connectedIPod == nil)

            Button {
                let result = AutoMixApplier.refreshAllMixes(ipodManager: ipodManager)
                applyResult = result.mixes > 0
                    ? "Refreshed \(result.mixes) mixes (\(result.tracks) tracks) on iPod"
                    : "Not enough music on the iPod to build mixes yet (need 10+ songs)"
            } label: {
                Label("Refresh Auto Mixes", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(deviceManager.connectedIPod == nil)
            .help("Builds Spotify-style Daily Mixes, Discovery, Heavy Rotation and Throwback playlists from the music on your iPod")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var playlistList: some View {
        List(selection: $selectedPlaylistId) {
            Section("ON iPOD") {
                if userPlaylists.isEmpty {
                    Text("No playlists yet")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                ForEach(userPlaylists) { pl in
                    HStack {
                        Image(systemName: pl.isPodcast ? "antenna.radiowaves.left.and.right" : "music.note.list")
                            .foregroundColor(pl.isPodcast ? .purple : .accentColor)
                        VStack(alignment: .leading) {
                            Text(pl.name)
                            Text("\(pl.trackCount) tracks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(pl.id)
                    .contextMenu {
                        Button("Rename...") {
                            renameText = pl.name
                            renamingPlaylist = pl
                        }
                        Button("Export as Files + M3U...") {
                            exportPlaylist(pl)
                        }
                        Button("Delete Playlist", role: .destructive) {
                            ipodManager.deletePlaylist(id: pl.id)
                            if selectedPlaylistId == pl.id { selectedPlaylistId = nil }
                        }
                    }
                }
            }

            Section("AUTO MIXES (PREVIEW)") {
                let mixes = AutoMixEngine.generateAll(tracks: ipodManager.deviceTracks)
                if mixes.isEmpty {
                    Text("Add 10+ songs to the iPod, then refresh to get Daily Mixes")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                ForEach(mixes) { mix in
                    HStack {
                        Image(systemName: mix.icon)
                            .foregroundColor(.pink)
                        VStack(alignment: .leading) {
                            Text(mix.name)
                            Text("\(mix.subtitle) · \(mix.tracks.count) tracks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Apply") {
                            let count = AutoMixApplier.apply(mix, to: ipodManager)
                            applyResult = "\"\(mix.name)\" written to iPod with \(count) tracks"
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }

            Section("SMART PLAYLISTS") {
                if smartStore.smartPlaylists.isEmpty {
                    Text("Rule-based playlists rebuilt on demand")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                ForEach(smartStore.smartPlaylists) { sp in
                    HStack {
                        Image(systemName: "gearshape.2")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text(sp.name)
                            Text("\(sp.rules.count) rule\(sp.rules.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Apply") {
                            let count = smartStore.apply(sp, to: ipodManager)
                            applyResult = "\"\(sp.name)\" updated with \(count) tracks on iPod"
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .contextMenu {
                        Button("Edit...") {
                            editingSmartPlaylist = sp
                            showSmartEditor = true
                        }
                        Button("Apply to iPod") {
                            let count = smartStore.apply(sp, to: ipodManager)
                            applyResult = "\"\(sp.name)\" updated with \(count) tracks on iPod"
                        }
                        Button("Delete", role: .destructive) {
                            smartStore.delete(id: sp.id)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var playlistDetail: some View {
        if let plId = selectedPlaylistId,
           let pl = userPlaylists.first(where: { $0.id == plId }) {
            PlaylistDetailView(playlist: pl)
        } else {
            emptyState(icon: "music.note.list", title: "Select a Playlist", message: "Choose a playlist to view and edit its tracks.")
        }
    }

    private func exportPlaylist(_ pl: PlaylistModel) {
        let byIpodId = Dictionary(grouping: ipodManager.deviceTracks, by: { $0.ipodTrackId ?? 0 })
        let tracks = pl.trackIds.compactMap { byIpodId[$0]?.first }
        guard !tracks.isEmpty else {
            applyResult = "Playlist is empty."
            return
        }
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to export the playlist into"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await IPodExporter.shared.exportPlaylist(name: pl.name, tracks: tracks, to: url)
            applyResult = IPodExporter.shared.summary
        }
    }

    private func importM3U() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.init(filenameExtension: "m3u8") ?? .plainText, .init(filenameExtension: "m3u") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }

        let entries = M3U.parse(text)
        guard !entries.isEmpty else {
            applyResult = "No entries found in that M3U file."
            return
        }

        // Match entries to device tracks by artist+title (loose), else title only
        var byLoose: [String: TrackModel] = [:]
        var byTitle: [String: TrackModel] = [:]
        for track in ipodManager.deviceTracks {
            byLoose[PlaylistBackup.looseKey(title: track.displayTitle, artist: track.displayArtist)] = track
            byTitle[DuplicateFinder.normalize(track.displayTitle)] = track
        }
        var matchedIds: [UInt32] = []
        var missing = 0
        for entry in entries {
            let track = byLoose[PlaylistBackup.looseKey(title: entry.title, artist: entry.artist)]
                ?? byTitle[DuplicateFinder.normalize(entry.title)]
            if let tid = track?.ipodTrackId {
                matchedIds.append(tid)
            } else {
                missing += 1
            }
        }

        let name = url.deletingPathExtension().lastPathComponent
        if ipodManager.playlistNamed(name) == nil {
            ipodManager.createPlaylist(name: name)
        }
        guard let target = ipodManager.playlistNamed(name) else { return }
        ipodManager.setPlaylistContents(playlistId: target.id, ipodTrackIds: matchedIds)
        applyResult = "Imported \"\(name)\" with \(matchedIds.count) tracks" + (missing > 0 ? " (\(missing) not on this iPod)" : "")
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Playlist Detail

struct PlaylistDetailView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager

    let playlist: PlaylistModel

    @State private var selection = Set<TrackModel.ID>()
    @State private var showAddPicker = false

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    /// Tracks in this playlist, in playlist order.
    private var tracks: [TrackModel] {
        let byIpodId = Dictionary(grouping: ipodManager.deviceTracks, by: { $0.ipodTrackId ?? 0 })
        return playlist.trackIds.compactMap { byIpodId[$0]?.first }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(playlist.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(tracks.count) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    showAddPicker = true
                } label: {
                    Label("Add Tracks", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(12)

            Divider()

            Table(tracks, selection: $selection) {
                TableColumn("Title") { (track: TrackModel) in
                    Text(track.displayTitle).fontWeight(.medium)
                }
                .width(min: 150, ideal: 260)
                TableColumn("Artist") { (track: TrackModel) in
                    Text(track.displayArtist)
                }
                TableColumn("Album") { (track: TrackModel) in
                    Text(track.displayAlbum)
                }
            }
            .contextMenu(forSelectionType: TrackModel.ID.self) { sel in
                Button(role: .destructive) {
                    let ids = tracks.filter { sel.contains($0.id) }.compactMap { $0.ipodTrackId }
                    ipodManager.removeTracksFromPlaylist(ipodTrackIds: ids, playlistId: playlist.id)
                } label: {
                    Label("Remove from Playlist", systemImage: "minus.circle")
                }
            } primaryAction: { sel in
                if let id = sel.first, let track = tracks.first(where: { $0.id == id }) {
                    audioPlayer.play(track: track)
                }
            }
        }
        .sheet(isPresented: $showAddPicker) {
            AddTracksToPlaylistSheet(playlist: playlist)
        }
    }
}

// MARK: - Add Tracks Sheet

struct AddTracksToPlaylistSheet: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss

    let playlist: PlaylistModel

    @State private var selection = Set<TrackModel.ID>()
    @State private var searchText = ""

    private var ipodManager: IPodManager { deviceManager.ipodManager }

    private var candidates: [TrackModel] {
        let existing = Set(playlist.trackIds)
        let available = ipodManager.deviceTracks.filter { track in
            guard let tid = track.ipodTrackId else { return false }
            return !existing.contains(tid) && (track.ipodMediaType == 1 || track.ipodMediaType == 0)
        }
        guard !searchText.isEmpty else { return available }
        return available.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.displayArtist.localizedCaseInsensitiveContains(searchText) ||
            $0.displayAlbum.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add to \"\(playlist.name)\"")
                    .font(.headline)
                Spacer()
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            .padding(12)

            Divider()

            Table(candidates, selection: $selection) {
                TableColumn("Title") { (t: TrackModel) in Text(t.displayTitle) }
                TableColumn("Artist") { (t: TrackModel) in Text(t.displayArtist) }
                TableColumn("Album") { (t: TrackModel) in Text(t.displayAlbum) }
            }

            Divider()

            HStack {
                Text("\(selection.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add \(selection.count) Tracks") {
                    ipodManager.addTracksToPlaylist(trackUUIDs: selection, playlistId: playlist.id)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
            .padding(12)
        }
        .frame(width: 640, height: 460)
    }
}

// MARK: - Smart Playlist Editor

struct SmartPlaylistEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject private var smartStore = SmartPlaylistStore.shared

    @State var playlist: SmartPlaylist
    let isNew: Bool

    @State private var limitEnabled: Bool = false
    @State private var limitValue: Int = 25

    private var matchCount: Int {
        playlist.evaluate(tracks: deviceManager.ipodManager.deviceTracks).count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New Smart Playlist" : "Edit Smart Playlist")
                    .font(.headline)
                Spacer()
            }
            .padding(12)

            Divider()

            Form {
                TextField("Name:", text: $playlist.name)

                Picker("Match:", selection: $playlist.matchAll) {
                    Text("All rules").tag(true)
                    Text("Any rule").tag(false)
                }
                .pickerStyle(.segmented)

                Section("Rules") {
                    ForEach($playlist.rules) { $rule in
                        HStack {
                            Picker("", selection: $rule.field) {
                                ForEach(SmartRule.Field.allCases, id: \.self) { f in
                                    Text(f.label).tag(f)
                                }
                            }
                            .frame(width: 130)
                            .onChange(of: rule.field) { newField in
                                if !SmartRule.Operator.valid(for: newField).contains(rule.op) {
                                    rule.op = SmartRule.Operator.valid(for: newField).first ?? .isEqual
                                }
                            }

                            Picker("", selection: $rule.op) {
                                ForEach(SmartRule.Operator.valid(for: rule.field), id: \.self) { op in
                                    Text(op.label).tag(op)
                                }
                            }
                            .frame(width: 150)

                            TextField("Value", text: $rule.value)

                            Button {
                                playlist.rules.removeAll { $0.id == rule.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button {
                        playlist.rules.append(SmartRule())
                    } label: {
                        Label("Add Rule", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }

                Section {
                    Toggle("Limit to", isOn: $limitEnabled)
                    if limitEnabled {
                        HStack {
                            Stepper(value: $limitValue, in: 1...500) {
                                Text("\(limitValue) tracks")
                            }
                            Picker("sorted by", selection: $playlist.sortField) {
                                ForEach(SmartPlaylist.SortField.allCases, id: \.self) { f in
                                    Text(f.label).tag(f)
                                }
                            }
                        }
                    }
                }

                if deviceManager.connectedIPod != nil {
                    Text("Currently matches \(matchCount) tracks on the connected iPod.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    playlist.limit = limitEnabled ? limitValue : nil
                    smartStore.upsert(playlist)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(playlist.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 600, height: 480)
        .onAppear {
            limitEnabled = playlist.limit != nil
            limitValue = playlist.limit ?? 25
            if playlist.rules.isEmpty {
                playlist.rules.append(SmartRule())
            }
        }
    }
}
