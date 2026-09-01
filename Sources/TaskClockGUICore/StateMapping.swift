import Foundation

// Pure display-state mapping: CLI/API values in, UI-ready strings and
// symbols out. All time-dependent output takes `now` as a parameter.

/// A task's display state, ordered by severity for menu-bar aggregation.
public enum TaskDisplayState: Int, Comparable, Sendable {
    case disabled = 0
    case paused = 1
    case idle = 2
    case running = 3
    case overrun = 4

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public func displayState(for task: TaskView) -> TaskDisplayState {
    if !task.enabled { return .disabled }
    if task.overrunSeconds > 0 { return .overrun }
    if task.running != nil { return .running }
    if task.paused { return .paused }
    return .idle
}

/// The menu-bar item's content. The bar must stay quiet in the normal case
/// and speak only in states that need the user: overrun and daemon-down.
public struct MenuBarSummary: Equatable, Sendable {
    public var symbolName: String
    /// Short text next to the symbol; nil in the quiet states.
    public var text: String?
}

public func menuBarSummary(tasks: [TaskView], daemonUp: Bool) -> MenuBarSummary {
    guard daemonUp else {
        // Unreachable daemon is "unknown", not "error" — a distinct symbol,
        // never silently the normal one.
        return MenuBarSummary(symbolName: Symbols.barDaemonDown, text: nil)
    }
    let worst = tasks.map(displayState(for:)).max() ?? .idle
    switch worst {
    case .overrun:
        let seconds = tasks.map(\.overrunSeconds).max() ?? 0
        return MenuBarSummary(
            symbolName: Symbols.barOverrun,
            text: compactDuration(seconds))
    case .running:
        return MenuBarSummary(symbolName: Symbols.barRunning, text: nil)
    default:
        return MenuBarSummary(symbolName: Symbols.barHealthy, text: nil)
    }
}

/// "42s" / "12m" / "1h32m" — deliberately coarse; the popover has the detail.
public func compactDuration(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    if s < 60 { return "\(s)s" }
    let m = s / 60
    if m < 60 { return "\(m)m" }
    return "\(m / 60)h\(m % 60 == 0 ? "" : "\(m % 60)m")"
}

/// The task row's leading indicator, in the same color grammar as the
/// daemon pilot lamp: green = healthy/active, orange = needs attention,
/// red = failed, gray = deliberately off (config-disabled or switch off).
/// A healthy idle task is green — gray would read as "inert" (user
/// feedback), and idle-on-schedule is the healthy normal state.
public enum RowIndicator: Equatable, Sendable {
    case disabled   // config `enabled = false` — gray
    case paused     // switch off — gray
    case overrun    // running past a due fire — orange
    case running    // green (normal operation in progress)
    case failed     // last run exited non-zero — red
    case missedLast // last fire was dropped — orange
    case healthy    // scheduled and fine — green
}

public func rowIndicator(for task: TaskView) -> RowIndicator {
    if !task.enabled { return .disabled }
    if task.overrunSeconds > 0 { return .overrun }
    if task.running != nil { return .running }
    if task.paused { return .paused }
    if let run = task.lastRun {
        if let exit = run.exitCode, exit != 0 { return .failed }
        if run.outcome == "missed" { return .missedLast }
    }
    return .healthy
}

/// One task row's display strings.
public struct TaskRowText: Equatable, Sendable {
    public var state: String    // "idle" / "running 3m" / "running 42m — overrun 12m" / "paused" / "disabled"
    public var nextRun: String  // "in 12m (10:30)" / "after current run" / "on success + 30m" / "—"
    public var lastRun: String  // "ok 10:00" / "exit 1 09:30" / "missed(overlap) 09:00" / "—"
    public var trigger: String  // "*/30 * * * *" / "success + 30m"
}

public func taskRowText(_ task: TaskView, now: Date) -> TaskRowText {
    TaskRowText(
        state: stateText(task, now: now),
        nextRun: nextRunText(task, now: now),
        lastRun: lastRunText(task),
        trigger: task.watermark.isEmpty ? task.cron : "success + \(task.watermark)"
    )
}

func stateText(_ task: TaskView, now: Date) -> String {
    switch displayState(for: task) {
    case .disabled: return "disabled"
    case .paused: return "paused"
    case .idle: return "idle"
    case .running:
        let elapsed = task.running.map { now.timeIntervalSince($0.startedAt) } ?? 0
        return "running \(compactDuration(max(0, elapsed)))"
    case .overrun:
        let elapsed = task.running.map { now.timeIntervalSince($0.startedAt) } ?? 0
        // Overrun is an explicit state word, never a negative countdown.
        return "running \(compactDuration(max(0, elapsed))) — overrun \(compactDuration(task.overrunSeconds))"
    }
}

func nextRunText(_ task: TaskView, now: Date) -> String {
    switch task.nextExpectedRun.kind {
    case "after_current":
        return "after current run"
    case "after_success":
        return task.watermark.isEmpty ? "after success" : "on success + \(task.watermark)"
    case "at":
        guard let at = task.nextExpectedRun.at else { return "—" }
        let delta = at.timeIntervalSince(now)
        let clock = shortClock(at)
        return delta <= 0 ? "due now (\(clock))" : "in \(compactDuration(delta)) (\(clock))"
    default:
        return "—"
    }
}

func lastRunText(_ task: TaskView) -> String {
    guard let run = task.lastRun else { return "—" }
    if run.outcome == "missed" {
        let reason = run.missedReason.isEmpty ? "" : "(\(run.missedReason))"
        return "missed\(reason) \(shortClock(run.scheduledFor))"
    }
    guard let finished = run.finishedAt else { return "in progress" }
    if let exit = run.exitCode, exit == 0 {
        return "ok \(shortClock(finished))"
    }
    let exit = run.exitCode.map(String.init) ?? "?"
    return "exit \(exit) \(shortClock(finished))"
}

func shortClock(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}
