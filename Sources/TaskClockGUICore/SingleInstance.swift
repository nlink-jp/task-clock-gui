import Foundation

/// Startup single-instance guard decision.
///
/// macOS can start a second copy of the app while one is already running:
/// notification-banner clicks resolve the bundle identifier among *all*
/// LaunchServices-registered copies (dev build in `dist/`, `/Applications`)
/// and may pick a different copy than the running one.
/// `LSMultipleInstancesProhibited` in Info.plist is the LS-level guard; this
/// decision covers the launch paths LS does not see (direct binary exec,
/// `open -n`).
public enum SingleInstanceDecision: Equatable, Sendable {
    case proceed
    case exitDuplicate(message: String)
}

public func singleInstanceDecision(
    bundleID: String?,
    ownPID: Int32,
    instancePIDs: [Int32]
) -> SingleInstanceDecision {
    guard bundleID != nil else { return .proceed }
    let others = instancePIDs.filter { $0 != ownPID }
    guard !others.isEmpty else { return .proceed }
    let pids = others.map(String.init).joined(separator: ", ")
    return .exitDuplicate(
        message: "task-clock-gui: another instance is already running (pid \(pids)) — exiting"
    )
}
