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

    // Task/run row indicators.
    public static let indicatorDisabled = "minus.circle"
    public static let indicatorPaused = "pause.circle"
    public static let indicatorOverrun = "exclamationmark.circle.fill"
    public static let indicatorRunning = "play.circle.fill"
    public static let indicatorFailed = "xmark.circle.fill"
    public static let indicatorMissed = "exclamationmark.triangle.fill"

    // Controls and adornments.
    public static let runNow = "play.fill"
    public static let runNowArmed = "play.circle.fill"
    public static let revealLog = "doc.text.magnifyingglass"
    public static let historyChevron = "chevron.right"
    public static let historyBack = "chevron.backward"
    public static let errorLabel = "exclamationmark.triangle"

    /// The complete inventory for the resolution test.
    public static let all: [String] = [
        barHealthy, barRunning, barOverrun, barDaemonDown,
        indicatorDisabled, indicatorPaused, indicatorOverrun,
        indicatorRunning, indicatorFailed, indicatorMissed,
        runNow, runNowArmed, revealLog, historyChevron, historyBack,
        errorLabel,
    ]
}
