import Foundation

/// Central place for the app's version information.
/// Keep `version`/`build` in sync with build_app.sh (which writes Info.plist).
enum AppInfo {
    static let version = "2.2.0"
    static let build = "6"

    /// Version as reported by the app bundle, falling back to the compiled-in
    /// constant when running outside a packaged .app (e.g. swift run).
    static var displayVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? version
    }

    static var displayBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? build
    }

    static var versionString: String {
        "PodSync v\(displayVersion) (\(displayBuild))"
    }
}
