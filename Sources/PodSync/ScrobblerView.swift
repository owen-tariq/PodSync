import SwiftUI

struct ScrobblerView: View {
    @EnvironmentObject var scrobblerManager: ScrobblerManager
    @EnvironmentObject var deviceManager: DeviceManager
    
    var body: some View {
        VStack(spacing: 0) {
            if scrobblerManager.sessionKey == nil {
                unauthenticatedState
            } else {
                authenticatedState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Last.fm Scrobbler")
    }
    
    // MARK: - Unauthenticated State
    
    @ViewBuilder
    private var unauthenticatedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "lastfm.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("Connect to Last.fm")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Sync your iPod's playback history directly to your Last.fm profile.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let error = scrobblerManager.authError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if scrobblerManager.isWaitingForBrowser {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Waiting for authorization in your browser...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("I have authorized the app") {
                        Task {
                            await scrobblerManager.completeWebAuthentication()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
            } else {
                Button("Connect with Last.fm") {
                    Task {
                        await scrobblerManager.startWebAuthentication()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Authenticated State
    
    @ViewBuilder
    private var authenticatedState: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Connected as \(scrobblerManager.username)")
                        .font(.headline)
                    Text("Your iPod listening history is ready to sync.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Disconnect") {
                    scrobblerManager.logout()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // List
            if scrobblerManager.pendingScrobbles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("You're all caught up!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("No new plays found on your iPod since the last sync.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(scrobblerManager.pendingScrobbles) { scrobble in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(scrobble.title)
                                    .fontWeight(.medium)
                                Text(scrobble.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(scrobble.playCountDelta) new plays")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                                Text(scrobble.lastPlayedTime, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Footer
                HStack {
                    Text("\(scrobblerManager.pendingScrobbles.count) tracks waiting to be scrobbled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Scrobble Now") {
                        Task {
                            await scrobblerManager.scrobblePending()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(scrobblerManager.isAuthenticating)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}
