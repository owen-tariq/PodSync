import Foundation
import CryptoKit
import Combine
import CLibGPod
import AppKit

struct PendingScrobble: Identifiable, Hashable {
    let id = UUID()
    let trackId: UInt32
    let title: String
    let artist: String
    let playCountDelta: Int
    let lastPlayedTime: Date
}

@MainActor
class ScrobblerManager: ObservableObject {
    static let shared = ScrobblerManager()
    
    @Published var apiKey: String = ""
    @Published var apiSecret: String = ""
    @Published var username: String = ""
    @Published var sessionKey: String? = nil
    @Published var authToken: String? = nil
    @Published var isAuthenticating: Bool = false
    @Published var isWaitingForBrowser: Bool = false
    @Published var authError: String? = nil
    
    @Published var pendingScrobbles: [PendingScrobble] = []
    
    // Store last known playcounts in UserDefaults
    private let playcountsKey = "ScrobblerManager_Playcounts"
    var lastKnownPlaycounts: [String: Int] {
        get {
            UserDefaults.standard.dictionary(forKey: playcountsKey) as? [String: Int] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: playcountsKey)
        }
    }
    
    init() {
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "LastFMAPIKey") as? String ?? "b944ba68dff884e232e0e288628beb59"
        self.apiSecret = Bundle.main.object(forInfoDictionaryKey: "LastFMAPISecret") as? String ?? "a5cee75e84a11bcb2d1c7a02158fe580"
        self.sessionKey = UserDefaults.standard.string(forKey: "LastFMSessionKey")
        self.username = UserDefaults.standard.string(forKey: "LastFMUsername") ?? ""
    }
    
    func logout() {
        sessionKey = nil
        username = ""
        UserDefaults.standard.removeObject(forKey: "LastFMSessionKey")
        UserDefaults.standard.removeObject(forKey: "LastFMUsername")
    }
    
    // Step 1: Get Token and Open Browser
    func startWebAuthentication() async {
        isAuthenticating = true
        authError = nil
        
        var params: [String: String] = [
            "method": "auth.getToken",
            "api_key": apiKey
        ]
        
        let sig = generateSignature(for: params, secret: apiSecret)
        params["api_sig"] = sig
        params["format"] = "json"
        
        var request = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
        request.httpMethod = "POST"
        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                self.authToken = token
                self.isWaitingForBrowser = true
                
                // Open browser
                if let url = URL(string: "https://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)") {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #endif
                }
            } else {
                self.authError = "Failed to get auth token"
            }
        } catch {
            self.authError = error.localizedDescription
        }
        
        isAuthenticating = false
    }
    
    // Step 2: Complete Authentication with Token
    func completeWebAuthentication() async {
        guard let token = authToken else { return }
        
        isAuthenticating = true
        authError = nil
        
        var params: [String: String] = [
            "method": "auth.getSession",
            "api_key": apiKey,
            "token": token
        ]
        
        let sig = generateSignature(for: params, secret: apiSecret)
        params["api_sig"] = sig
        params["format"] = "json"
        
        var request = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
        request.httpMethod = "POST"
        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let session = json["session"] as? [String: Any],
               let key = session["key"] as? String,
               let name = session["name"] as? String {
                self.sessionKey = key
                self.username = name
                self.isWaitingForBrowser = false
                self.authToken = nil
                
                UserDefaults.standard.set(key, forKey: "LastFMSessionKey")
                UserDefaults.standard.set(name, forKey: "LastFMUsername")
            } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let msg = json["message"] as? String {
                self.authError = msg
            } else {
                self.authError = "Unknown error"
            }
        } catch {
            self.authError = error.localizedDescription
        }
        
        isAuthenticating = false
    }
    
    func addPendingScrobbles(_ newScrobbles: [PendingScrobble]) {
        self.pendingScrobbles.append(contentsOf: newScrobbles)
    }
    
    // Extracts playback history from the libgpod database
    nonisolated static func extractHistoryBackground(from dbRaw: OpaquePointer, currentPlaycounts: [String: Int]) -> [PendingScrobble] {
        var count: UInt32 = 0
        guard let trackArray = gpod_get_all_tracks(dbRaw, &count) else { return [] }
        
        var newPending: [PendingScrobble] = []
        
        for i in 0..<Int(count) {
            guard let trackPtr = trackArray[i] else { continue }
            let track = OpaquePointer(trackPtr)
            
            let id = gpod_track_get_id_field(track)
            let playcount = Int(gpod_track_get_playcount_field(track))
            let timePlayed = gpod_track_get_time_played(track)
            
            let idKey = String(id)
            let lastPlaycount = currentPlaycounts[idKey] ?? 0
            
            if playcount > lastPlaycount {
                let delta = playcount - lastPlaycount
                
                let titlePtr = gpod_track_get_title_field(track)
                let title = titlePtr != nil ? String(cString: titlePtr!) : "Unknown Track"
                
                let artistPtr = gpod_track_get_artist_field(track)
                let artist = artistPtr != nil ? String(cString: artistPtr!) : "Unknown Artist"
                
                let lastDate = Date(timeIntervalSince1970: TimeInterval(timePlayed))
                
                newPending.append(PendingScrobble(
                    trackId: id,
                    title: title,
                    artist: artist,
                    playCountDelta: delta,
                    lastPlayedTime: lastDate
                ))
            }
        }
        
        gpod_free_track_array(trackArray)
        
        return newPending
    }
    
    // Scrobble all pending tracks
    func scrobblePending() async {
        guard let sk = sessionKey else { return }
        isAuthenticating = true
        
        var successCount = 0
        var currentPlaycounts = lastKnownPlaycounts
        
        for scrobble in pendingScrobbles {
            // We dispatch one scrobble per play count delta
            var scrobbleSuccess = true
            for offset in 0..<scrobble.playCountDelta {
                // Offset timestamp slightly to avoid identical timestamps
                let timestamp = Int(scrobble.lastPlayedTime.timeIntervalSince1970) - (offset * 180)
                
                var params: [String: String] = [
                    "method": "track.scrobble",
                    "artist": scrobble.artist,
                    "track": scrobble.title,
                    "timestamp": "\(timestamp)",
                    "api_key": apiKey,
                    "sk": sk
                ]
                
                let sig = generateSignature(for: params, secret: apiSecret)
                params["api_sig"] = sig
                params["format"] = "json"
                
                var request = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
                request.httpMethod = "POST"
                request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)
                
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let scrobbles = json["scrobbles"] as? [String: Any],
                       let attr = scrobbles["@attr"] as? [String: Any],
                       let accepted = attr["accepted"] as? Int, accepted > 0 {
                        // Success
                    } else {
                        scrobbleSuccess = false
                    }
                } catch {
                    scrobbleSuccess = false
                }
            }
            
            if scrobbleSuccess {
                successCount += 1
                let idKey = String(scrobble.trackId)
                currentPlaycounts[idKey] = (currentPlaycounts[idKey] ?? 0) + scrobble.playCountDelta
            }
        }
        
        // Update local state
        lastKnownPlaycounts = currentPlaycounts
        pendingScrobbles.removeAll()
        isAuthenticating = false
    }
    
    private func generateSignature(for params: [String: String], secret: String) -> String {
        let sortedKeys = params.keys.sorted()
        var str = ""
        for key in sortedKeys {
            str += key + params[key]!
        }
        str += secret
        
        let digest = Insecure.MD5.hash(data: str.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
