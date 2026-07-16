import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()
    
    @Published var isPlaying: Bool = false
    @Published var currentTrack: TrackModel? = nil
    
    private var player: AVAudioPlayer?
    
    override private init() {
        super.init()
    }
    
    func play(track: TrackModel) {
        guard FileManager.default.fileExists(atPath: track.filePath.path) else {
            print("[AudioPlayerManager] File not found at path: \(track.filePath.path)")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: track.filePath)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            
            self.currentTrack = track
            self.isPlaying = true
        } catch {
            print("[AudioPlayerManager] Failed to play audio: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func resume() {
        player?.play()
        isPlaying = true
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if player != nil {
            resume()
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTrack = nil
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTrack = nil
        }
    }
}
