import Foundation

// Display mapping for the per-task run-history view (GUI Phase 2). Same
// color grammar as the task rows: green = fine, orange = dropped fire,
// red = failed, and the mapping stays a pure, tested function.

/// Indicator for one history row, reusing the task-row vocabulary.
public func runRowIndicator(for run: Run) -> RowIndicator {
    if run.outcome == "missed" { return .missedLast }
    if run.startedAt != nil && run.finishedAt == nil { return .running }
    if let exit = run.exitCode, exit != 0 { return .failed }
    return .healthy
}

/// One history row's display strings.
public struct RunRowText: Equatable, Sendable {
    /// The scheduled fire, seconds included — minute-cadence tasks make
    /// HH:mm collide.
    public var clock: String
    /// How far past the schedule the run started ("+8s"), "" when on the
    /// tick, "—" when it never started.
    public var startDelay: String
    /// Run duration, "running" while in flight, "—" for missed fires.
    public var duration: String
    /// "ok" / "exit 3" / "missed(overlap)" / "running", with the outcome
    /// appended when it carries information ("ok (queued)", "ok (manual)").
    public var result: String
}

public func runRowText(_ run: Run) -> RunRowText {
    let clock = clockWithSeconds(run.scheduledFor)

    if run.outcome == "missed" {
        let reason = run.missedReason.isEmpty ? "" : "(\(run.missedReason))"
        return RunRowText(clock: clock, startDelay: "—", duration: "—", result: "missed\(reason)")
    }

    var startDelay = "—"
    if let started = run.startedAt {
        let delay = started.timeIntervalSince(run.scheduledFor)
        startDelay = delay >= 1 ? "+" + compactDuration(delay) : ""
    }

    guard let started = run.startedAt else {
        return RunRowText(clock: clock, startDelay: startDelay, duration: "—", result: run.outcome)
    }
    guard let finished = run.finishedAt else {
        return RunRowText(clock: clock, startDelay: startDelay, duration: "running", result: "running")
    }

    let duration = compactDuration(max(0, finished.timeIntervalSince(started)))
    var result: String
    if let exit = run.exitCode {
        result = exit == 0 ? "ok" : "exit \(exit)"
    } else {
        result = run.outcome
    }
    if run.outcome == "queued" || run.outcome == "manual" {
        result += " (\(run.outcome))"
    }
    return RunRowText(clock: clock, startDelay: startDelay, duration: duration, result: result)
}

func clockWithSeconds(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: date)
}
