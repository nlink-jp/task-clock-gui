import Foundation
import TaskClockGUICore

/// Reads the daemon's launchd-side state. The run intent lives in
/// launchd's persistent disable records (`task-clock stop` disables the
/// service so a deliberate stop survives logins); the GUI reads it back to
/// tell gray "stopped by you" from orange "should be running but isn't".
enum DaemonControl {
    /// Whether the service is enabled (runnable) in the user's gui domain.
    /// An unreadable dump answers "enabled" — that is launchd's default,
    /// and inventing a deliberate stop would silently mute the
    /// daemon-unreachable notification.
    static func isEnabled() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["print-disabled", "gui/\(getuid())"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            return true
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return daemonEnabledInDump(String(data: data, encoding: .utf8) ?? "")
    }
}
