import Foundation

/// The daemon pilot lamp: one persistent indicator + power switch replaces
/// the earlier asymmetric UI (a big button when down, a checkbox when up —
/// user feedback). The lamp shows the *actual* state, the switch holds the
/// *intent* (launch-agent registration); they are deliberately independent,
/// which is how "installed" and "reachable" being distinct states becomes
/// visible: a registered-but-dead daemon is an orange lamp on an ON switch.
public enum DaemonLampState: Equatable, Sendable {
    /// The API answers (whether via the launch agent or a foreground serve).
    case running
    /// Registered but not answering — starting up, or broken.
    case stalled
    /// Not registered, not answering.
    case stopped
}

public func daemonLamp(installed: Bool, up: Bool) -> DaemonLampState {
    if up { return .running }
    return installed ? .stalled : .stopped
}

public func daemonLampText(_ state: DaemonLampState) -> String {
    switch state {
    case .running: return "Daemon running"
    case .stalled: return "Daemon not responding"
    case .stopped: return "Daemon stopped"
    }
}
