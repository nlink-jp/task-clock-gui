import Foundation

/// The daemon pilot lamp: one persistent indicator + power switch replaces
/// the earlier asymmetric UI (a big button when down, a checkbox when up —
/// user feedback). The lamp shows the *actual* state, the switch holds the
/// *run intent*; they are deliberately independent, which is how distinct
/// states become visible: an enabled-but-dead daemon is an orange lamp on
/// an ON switch.
///
/// Since the run/install separation (user feedback: stopping is a daily
/// operation, installing is setup — one switch for both meant "pausing the
/// fridge by unplugging it"), the switch flips only the run state
/// (`task-clock start` / `stop`); install/uninstall are separate explicit
/// actions.
public enum DaemonLampState: Equatable, Sendable {
    /// The API answers (whether via the launch agent or a foreground serve).
    case running
    /// Enabled but not answering — starting up, or broken.
    case stalled
    /// Installed but deliberately stopped (`task-clock stop`).
    case stopped
    /// No launch agent registered — setup has not happened.
    case notInstalled
}

public func daemonLamp(installed: Bool, enabled: Bool, up: Bool) -> DaemonLampState {
    if up { return .running }
    if !installed { return .notInstalled }
    return enabled ? .stalled : .stopped
}

public func daemonLampText(_ state: DaemonLampState) -> String {
    switch state {
    case .running: return "Daemon running"
    case .stalled: return "Daemon not responding"
    case .stopped: return "Daemon stopped"
    case .notInstalled: return "Daemon not installed"
    }
}
