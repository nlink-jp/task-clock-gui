import Foundation

/// After toggling launch-at-login, the actual state is re-read and compared
/// with what the user asked for. "No error but the switch snapped back" is
/// the worst outcome (org lesson: sensor-lens-gui) — when the state did not
/// take effect, say so, with where to fix it. SMAppService reports
/// `.requiresApproval` by leaving the status short of `.enabled`, so the
/// mismatch message points at System Settings.
public func loginItemFeedback(requested: Bool, nowEnabled: Bool) -> String? {
    if requested == nowEnabled { return nil }
    return requested
        ? "Launch at login is not active yet — approve it in System Settings › General › Login Items."
        : "Launch at login is still active — check System Settings › General › Login Items."
}
