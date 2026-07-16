import Foundation
import AppKit

/// Represents a detected iPod device on the system.
struct IPodDevice: Identifiable, Equatable {
    let id: UUID = UUID()
    let name: String
    let mountPath: URL
    let totalCapacity: Int64
    let availableCapacity: Int64
    
    var totalCapacityFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
    }
    
    var availableCapacityFormatted: String {
        ByteCountFormatter.string(fromByteCount: availableCapacity, countStyle: .file)
    }
    
    var usedCapacityFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity - availableCapacity, countStyle: .file)
    }
}

/// Listens for mounted volumes and detects iPods using NSWorkspace.
@MainActor
class DeviceManager: ObservableObject {
    @Published var connectedIPod: IPodDevice?
    @Published var ipodManager = IPodManager()
    
    init() {
        // Setup observers for mounting/unmounting
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(volumeDidMount(_:)),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(volumeDidUnmount(_:)),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
        
        // Scan currently mounted volumes at startup
        scanForIPod()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    /// Scan all mounted volumes to see if an iPod is currently attached.
    private func scanForIPod() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: .skipHiddenVolumes) else {
            return
        }
        
        for volume in volumes {
            if isIPod(at: volume) {
                connect(to: volume)
                return
            }
        }
    }
    
    @objc private func volumeDidMount(_ notification: Notification) {
        guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        
        if isIPod(at: volumeURL) {
            connect(to: volumeURL)
        }
    }
    
    @objc private func volumeDidUnmount(_ notification: Notification) {
        guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        
        if let currentIPod = connectedIPod, currentIPod.mountPath == volumeURL {
            connectedIPod = nil
            ipodManager.close()
        }
    }
    
    /// Determines if a mounted volume is an iPod by checking for the hidden `iPod_Control` directory.
    private func isIPod(at url: URL) -> Bool {
        let ipodControlPath = url.appendingPathComponent("iPod_Control")
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: ipodControlPath.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }
    
    /// Extracts volume information and sets the connected iPod.
    private func connect(to url: URL) {
        let path = url.path
        do {
            let values = try url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            
            let name = values.volumeName ?? url.lastPathComponent
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacity ?? 0)
            
            self.connectedIPod = IPodDevice(
                name: name,
                mountPath: url,
                totalCapacity: total,
                availableCapacity: available
            )
            
            // Parse database automatically
            self.ipodManager.openIPod(at: path)
            
            print("[DeviceManager] Detected iPod: \(name) at \(url.path)")
            
        } catch {
            print("[DeviceManager] Error reading volume attributes: \(error)")
        }
    }
}
