import Foundation

/// The LaunchAgent plist task-clock's `install` writes. Its label is a
/// documented contract of the CLI (jp.nlink.task-clock); the GUI reads only
/// the file's existence to answer "is the daemon set up to run?" — which is
/// deliberately distinct from "is it reachable right now" (a foreground
/// `task-clock serve` is up without being installed).
public func daemonPlistPath(home: String) -> String {
    home + "/Library/LaunchAgents/jp.nlink.task-clock.plist"
}

/// Post-action verification for the daemon toggle, same principle as
/// launch-at-login: report the state that actually took effect, and when it
/// does not match the request without an error, say so instead of letting
/// the switch silently snap back.
public func daemonInstallFeedback(requested: Bool, installedNow: Bool) -> String? {
    if requested == installedNow { return nil }
    return requested
        ? "The daemon did not get installed — run `task-clock install` in a terminal to see why."
        : "The daemon is still installed — run `task-clock uninstall` in a terminal to see why."
}
