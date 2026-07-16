import SwiftUI
import UniformTypeIdentifiers

// MARK: - App Entry Point

@main
struct PodSyncApp: App {
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var scrobblerManager = ScrobblerManager.shared
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    init() {
        setlinebuf(stdout)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryManager)
                .environmentObject(deviceManager)
                .environmentObject(scrobblerManager)
                .environmentObject(audioPlayer)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add File to Library...") {
                    addFileToLibrary()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Add Folder to Library...") {
                    libraryManager.addLibraryFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
    
    private func addFileToLibrary() {
        let panel = NSOpenPanel()
        panel.title = "Add File to Library"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio]
        
        if panel.runModal() == .OK {
            libraryManager.addFilesOrFolders(urls: panel.urls)
        }
    }
}

// MARK: - Sidebar Item

enum SidebarItem: Hashable {
    case library
    case albums
    case playlists
    case devices
    case deviceSongs
    case deviceAlbums
    case deviceArtists
    case deviceMovies
    case devicePodcasts
    case deviceAudiobooks
    case playlistDetail(UUID)
    case lastfm
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager

    @State private var selection: SidebarItem? = .library
    @State private var searchText: String = ""
    @State private var selectedTracks: Set<TrackModel.ID> = []
    @State private var isDeviceExpanded: Bool = true

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("PodSync")
                .listStyle(.sidebar)
        } detail: {
            detailContent
        }
        .onChange(of: selection) { newValue in
            if newValue == .devices {
                isDeviceExpanded = true
            }
        }
        .toolbar {
            toolbarContent
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        List(selection: $selection) {
            Section("LIBRARIES") {
                NavigationLink(value: SidebarItem.library) {
                    Label("All Music", systemImage: "music.note.list")
                }

                NavigationLink(value: SidebarItem.albums) {
                    Label("Albums", systemImage: "square.stack")
                }

                ForEach(libraryManager.libraryPaths, id: \.self) { path in
                    Label(path.lastPathComponent, systemImage: "folder.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            Section("DEVICES") {
                if let ipod = deviceManager.connectedIPod {
                    DisclosureGroup(isExpanded: $isDeviceExpanded) {
                        NavigationLink(value: SidebarItem.deviceSongs) {
                            Label("Music", systemImage: "music.note")
                        }
                        NavigationLink(value: SidebarItem.deviceMovies) {
                            Label("Movies", systemImage: "film")
                        }
                        NavigationLink(value: SidebarItem.devicePodcasts) {
                            Label("Podcasts", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        NavigationLink(value: SidebarItem.deviceAudiobooks) {
                            Label("Audiobooks", systemImage: "book")
                        }
                    } label: {
                        NavigationLink(value: SidebarItem.devices) {
                            Label(ipod.name, systemImage: "ipod")
                        }
                    }
                } else {
                    NavigationLink(value: SidebarItem.devices) {
                        Label("iPod", systemImage: "ipod")
                    }
                }
            }
            
            Section("SERVICES") {
                NavigationLink(value: SidebarItem.lastfm) {
                    Label("Last.fm", systemImage: "lastfm.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .library:
            TrackListView(searchText: $searchText, selectedTracks: $selectedTracks)
        case .albums:
            AlbumGridView()
        case .devices:
            DeviceView()
        case .deviceSongs:
            DeviceSongsView(mediaType: 1)
        case .deviceMovies:
            DeviceSongsView(mediaType: 2)
        case .devicePodcasts:
            DeviceSongsView(mediaType: 4)
        case .deviceAudiobooks:
            DeviceSongsView(mediaType: 8)
        case .deviceAlbums:
            DeviceAlbumsView()
        case .deviceArtists:
            DeviceArtistsView()
        case .playlists:
            Text("Playlists") // placeholder
        case .playlistDetail(let id):
            Text("Playlist \(id)") // placeholder
        case .lastfm:
            ScrobblerView()
        case .none:
            VStack(spacing: 12) {
                Image(systemName: "music.note.house")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Select an item from the sidebar")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }


    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                // Previous track
            } label: {
                Image(systemName: "backward.fill")
            }
            .help("Previous")

            Button(action: {
                audioPlayer.togglePlayPause()
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
            }
            
            Button(action: {
                // Next track logic
            }) {
                Image(systemName: "forward.fill")
            }
        }

        ToolbarItem(placement: .principal) {
            if let track = audioPlayer.currentTrack {
                Text(track.title ?? "Unknown Title")
                    .font(.headline)
            } else {
                Text("Not Playing")
                    .foregroundColor(.secondary)
            }
        }

    }
}
