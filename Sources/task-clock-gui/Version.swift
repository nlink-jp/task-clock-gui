import Foundation

/// The app's version: the bundle's short version in a packaged .app, a dev
/// marker when run as a bare binary (`swift run`).
let appVersion: String =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
