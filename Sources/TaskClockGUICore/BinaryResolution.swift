import Foundation

/// Pure CLI-binary resolution (injectable for tests). Order:
///   [env override, DEBUG builds only] → bundled → Homebrew/system paths → [devPaths]
///
/// The **bundled** copy in the .app's Resources is the trust anchor: it
/// ships Developer-ID signed + notarized inside the bundle, so it cannot be
/// swapped without invalidating the signature. In release builds no
/// environment variable can redirect execution — the binary being run reads
/// the config that holds the daemon API key.
public func resolveCLIBinary(
    env: [String: String],
    allowEnvOverride: Bool,
    bundled: String?,
    devPaths: [String],
    isExecutable: (String) -> Bool
) -> String? {
    var order: [String] = []
    if allowEnvOverride, let p = env["TASK_CLOCK_GUI_BIN"] {
        order.append(p)
    }
    if let bundled {
        order.append(bundled)
    }
    order += ["/opt/homebrew/bin/task-clock", "/usr/local/bin/task-clock"]
    order += devPaths
    return order.first(where: isExecutable)
}
