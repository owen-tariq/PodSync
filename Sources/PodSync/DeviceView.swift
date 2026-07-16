import SwiftUI

struct DeviceView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var libraryManager: LibraryManager
    
    @State private var isSyncing: Bool = false
    @State private var syncProgress: Double = 0.0
    @State private var syncStatusText: String = ""
    
    // Duplicate detection
    @State private var showDuplicateAlert: Bool = false
    @State private var duplicateCount: Int = 0
    @State private var newCount: Int = 0
    @State private var pendingSync: IPodDevice? = nil
    
    // No library warning
    @State private var showNoLibraryAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let ipod = deviceManager.connectedIPod {
                connectedView(for: ipod)
            } else {
                disconnectedView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Duplicate Songs Found", isPresented: $showDuplicateAlert) {
            Button("Skip Duplicates") {
                if let ipod = pendingSync {
                    Task { await startSync(ipod: ipod, skipDuplicates: true) }
                }
            }
            Button("Add All Anyway") {
                if let ipod = pendingSync {
                    Task { await startSync(ipod: ipod, skipDuplicates: false) }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSync = nil
            }
        } message: {
            Text("\(duplicateCount) song(s) already exist on your iPod.\n\(newCount) new song(s) will be added.\n\nWould you like to skip the duplicates or add them again?")
        }
        .alert("No Music Library", isPresented: $showNoLibraryAlert) {
            Button("Add Music Folder") {
                addMusicFolder()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You haven't added any music folder yet.\n\nAdd a folder containing your music files first, then tap Sync again.")
        }
    }
    
    // MARK: - Disconnected View
    
    private var disconnectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "ipod")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gray, .secondary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Connect your iPod")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect an iPod to your Mac to sync\nyour music library.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Supported: iPod Classic, iPod Nano, iPod Shuffle")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Connected View
    
    private func connectedView(for ipod: IPodDevice) -> some View {
        VStack(spacing: 30) {
            Image(systemName: "ipod")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text(ipod.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("\(deviceManager.ipodManager.deviceTracks.count) tracks · \(ipod.usedCapacityFormatted) used of \(ipod.totalCapacityFormatted)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Progress or Sync Button
            if isSyncing {
                VStack(spacing: 12) {
                    ProgressView(value: syncProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 300)
                    
                    Text(syncStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 16) {
                    Button {
                        if libraryManager.tracks.isEmpty {
                            showNoLibraryAlert = true
                        } else {
                            checkForDuplicatesAndSync(ipod: ipod)
                        }
                    } label: {
                        Label("Sync Music", systemImage: "arrow.triangle.2.circlepath")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                    
                    Button {
                        deviceManager.ipodManager.eject()
                    } label: {
                        Label("Eject", systemImage: "eject.fill")
                            .font(.title3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }
    
    // MARK: - Duplicate Check
    
    private func checkForDuplicatesAndSync(ipod: IPodDevice) {
        let manager = deviceManager.ipodManager
        let libraryTracks = libraryManager.tracks
        
        // Build a set of (title, artist) already on the iPod for fast lookup
        let existingSet: Set<String> = Set(
            manager.deviceTracks.map { track in
                let t = (track.title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let a = (track.artist ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                return "\(t)||\(a)"
            }
        )
        
        // Count duplicates
        var dupes = 0
        for track in libraryTracks {
            let t = (track.title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            let a = (track.artist ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            let key = "\(t)||\(a)"
            if existingSet.contains(key) {
                dupes += 1
            }
        }
        
        if dupes > 0 {
            // Found duplicates — ask the user
            duplicateCount = dupes
            newCount = libraryTracks.count - dupes
            pendingSync = ipod
            showDuplicateAlert = true
        } else {
            // No duplicates — sync everything
            Task { await startSync(ipod: ipod, skipDuplicates: false) }
        }
    }
    
    // MARK: - Sync Logic
    
    @MainActor
    private func startSync(ipod: IPodDevice, skipDuplicates: Bool) async {
        pendingSync = nil
        isSyncing = true
        syncProgress = 0.0
        syncStatusText = "Preparing..."
        
        let manager = deviceManager.ipodManager
        let libraryTracks = libraryManager.tracks
        
        // Build existing set for duplicate detection
        let existingSet: Set<String> = Set(
            manager.deviceTracks.map { track in
                let t = (track.title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let a = (track.artist ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                return "\(t)||\(a)"
            }
        )
        
        // Filter tracks to sync
        let tracksToSync: [TrackModel]
        if skipDuplicates {
            tracksToSync = libraryTracks.filter { track in
                let t = (track.title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                let a = (track.artist ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                return !existingSet.contains("\(t)||\(a)")
            }
        } else {
            tracksToSync = libraryTracks
        }
        
        if tracksToSync.isEmpty {
            syncStatusText = "All songs already on iPod!"
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isSyncing = false
            return
        }
        
        let total = tracksToSync.count
        var synced = 0
        
        for (index, track) in tracksToSync.enumerated() {
            syncProgress = Double(index) / Double(max(total, 1))
            syncStatusText = "Copying \(track.title ?? "Unknown Track")... (\(index + 1)/\(total))"
            
            let title = track.title ?? track.filePath.lastPathComponent
            let artist = track.artist ?? "Unknown Artist"
            let album = track.album ?? "Unknown Album"
            
            let success = manager.addTrack(
                filePath: track.filePath.path,
                title: title,
                artist: artist,
                album: album,
                artworkData: track.artworkData,
                duration: track.duration,
                size: track.fileSize,
                year: track.year,
                trackNum: track.trackNumber,
                discNum: track.discNumber
            )
            
            if success {
                synced += 1
            } else {
                print("[DeviceView] Failed to sync track: \(title)")
            }
            
            // Yield to let the UI update
            await Task.yield()
        }
        
        syncProgress = 1.0
        syncStatusText = "Saving Database..."
        let saveSuccess = manager.save()
        
        if saveSuccess {
            syncStatusText = "Sync Complete! Added \(synced) songs."
        } else {
            syncStatusText = "Error saving database!"
        }
        
        // Hide progress bar after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isSyncing = false
    }
    
    // MARK: - Add Music Folder
    
    private func addMusicFolder() {
        libraryManager.addLibraryFolder()
    }
}
