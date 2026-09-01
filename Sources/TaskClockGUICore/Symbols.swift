import Foundation

/// Every SF Symbol name the app can emit, in one place. Views must use
/// these constants, never string literals: a plausible-but-fake symbol
/// name fails neither compile nor runtime — it just renders blank. The
/// test suite resolves every name via NSImage, so a typo or a
/// wrong-variant edit breaks the build instead of the menu bar
/// (org lesson: "SF Symbol 名は実在を検証してから使う").
public enum Symbols {
    // Menu-bar states (also emitted by menuBarSummary in StateMapping).
    public static let barHealthy = "clock"
    public static let barRunning = "clock.arrow.circlepath"
    public static let barOverrun = "clock.badge.exclamationmark"
    public static let barDaemonDown = "clock.badge.questionmark"

    // Controls and adornments. Row/run state indicators are deliberately
    // NOT symbols: state is one visual idiom app-wide — a colored dot in
    // the daemon lamp's color grammar (green/orange/red/gray), with the
    // caption text carrying the reason. A symbol zoo next to dots was the
    // main source of visual noise (user feedback).
    public static let runNow = "play.fill"
    public static let runNowArmed = "play.circle.fill"
    public static let revealLog = "doc.text.magnifyingglass"
    public static let historyChevron = "chevron.right"
    public static let historyBack = "chevron.backward"
    public static let errorLabel = "exclamationmark.triangle"
    public static let reload = "arrow.clockwise"
    public static let installDaemon = "arrow.down.circle"
    public static let uninstallDaemon = "trash"
    public static let quitApp = "power"

    /// The complete inventory for the resolution test.
    public static let all: [String] = [
        barHealthy, barRunning, barOverrun, barDaemonDown,
        runNow, runNowArmed, revealLog, historyChevron, historyBack,
        errorLabel, reload, installDaemon, uninstallDaemon, quitApp,
    ]
}
