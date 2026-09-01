import Foundation

/// The LaunchAgent plist task-clock's `install` writes. Its label is a
/// documented contract of the CLI (jp.nlink.task-clock); the GUI reads only
/// the file's existence to answer "is the daemon set up to run?" — which is
/// deliberately distinct from "is it reachable right now" (a foreground
/// `task-clock serve` is up without being installed).
public func daemonPlistPath(home: String) -> String {
    home + "/Library/LaunchAgents/jp.nlink.task-clock.plist"
}

/// Post-action verification for install/uninstall, same principle as
/// launch-at-login: report the state that actually took effect, and when it
/// does not match the request without an error, say so instead of letting
/// the control silently snap back.
public func daemonInstallFeedback(requested: Bool, installedNow: Bool) -> String? {
    if requested == installedNow { return nil }
    return requested
        ? "The daemon did not get installed — run `task-clock install` in a terminal to see why."
        : "The daemon is still installed — run `task-clock uninstall` in a terminal to see why."
}

/// Post-action verification for the run-state switch (`task-clock start` /
/// `stop`), against the launchd enable record that carries the intent.
public func daemonRunFeedback(requested: Bool, enabledNow: Bool) -> String? {
    if requested == enabledNow { return nil }
    return requested
        ? "The daemon did not start — run `task-clock start` in a terminal to see why."
        : "The daemon did not stop — run `task-clock stop` in a terminal to see why."
}

/// Whether the label is runnable according to a `launchctl print-disabled
/// gui/<uid>` dump. launchd records a *deliberate* stop as a persistent
/// disable — which is exactly the "did the user turn it off?" question the
/// lamp needs, and what separates gray "stopped" from orange "stalled".
/// Modern launchctl prints `"label" => disabled`; older builds printed
/// `=> true` (true meaning disabled). A label that does not appear is
/// enabled — that is the launchd default, so an unreadable dump errs
/// toward enabled rather than inventing a deliberate stop.
public func daemonEnabledInDump(_ dump: String) -> Bool {
    for line in dump.split(separator: "\n") {
        guard line.contains("\"jp.nlink.task-clock\"") else { continue }
        return !(line.contains("disabled") || line.contains("true"))
    }
    return true
}
