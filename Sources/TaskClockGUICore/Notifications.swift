import Foundation

/// A notification-worthy transition between two consecutive status
/// snapshots. Edge-triggered by design: states that persist do not repeat
/// their banner every poll.
public struct NotifyEvent: Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

/// Compare two snapshots and list what deserves a banner:
/// - the daemon became unreachable **while still meant to run** (was up,
///   now down, launch agent installed AND enabled — KeepAlive failing is
///   an anomaly). A deliberate stop clears the intent (`task-clock stop`
///   disables, `uninstall` deregisters — the GUI switch and buttons go
///   through those), and an intentional stop is not an incident — no
///   banner (the lamp already shows gray "stopped")
/// - a task entered the overrun state
/// - a task's newest run finished with a failure (a new history row with a
///   non-zero exit)
///
/// The first snapshot after launch has no "old" to compare against — the
/// caller must not call this until a previous snapshot exists, so a state
/// that was already true at launch does not fire a stale banner.
public func transitionEvents(
    oldTasks: [TaskView], newTasks: [TaskView],
    wasDaemonUp: Bool, isDaemonUp: Bool,
    intendedUp: Bool
) -> [NotifyEvent] {
    var events: [NotifyEvent] = []

    if wasDaemonUp && !isDaemonUp {
        if intendedUp {
            events.append(NotifyEvent(
                id: "daemon-down",
                title: "task-clock daemon unreachable",
                body: "Scheduled tasks are not being run. Open the menu bar item to restart it."))
        }
        return events // task diffs against an unreachable daemon are noise
    }

    let oldByName = Dictionary(uniqueKeysWithValues: oldTasks.map { ($0.name, $0) })
    for task in newTasks {
        guard let previous = oldByName[task.name] else { continue }

        if displayState(for: task) == .overrun && displayState(for: previous) != .overrun {
            events.append(NotifyEvent(
                id: "overrun-\(task.name)",
                title: "\(task.name) is overrunning its schedule",
                body: "Running past its fire by \(compactDuration(task.overrunSeconds)); the next run waits."))
        }

        // "Newly failed" must also cover the run the previous poll saw
        // STILL OPEN under the same id (any run longer than one poll
        // interval) — a new-id check alone silences exactly those.
        if let run = task.lastRun, run.finishedAt != nil,
           let exit = run.exitCode, exit != 0,
           run.id != previous.lastRun?.id || previous.lastRun?.finishedAt == nil {
            events.append(NotifyEvent(
                id: "failure-\(task.name)-\(run.id)",
                title: "\(task.name) failed",
                body: run.error.isEmpty ? "Exited with code \(exit)." : run.error))
        }
    }
    return events
}
