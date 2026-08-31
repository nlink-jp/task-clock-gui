import XCTest
@testable import TaskClockGUICore

final class DecodeTests: XCTestCase {
    // A representative `task-clock status --json` payload (API pass-through).
    let statusJSON = """
    {"tasks":[
      {"name":"analyze","enabled":true,"cron":"*/30 * * * *","overlap":"queue-one",
       "catch_up":true,"next_fire":"2026-08-31T10:30:00Z",
       "next_expected_run":{"kind":"at","at":"2026-08-31T10:30:00Z"},
       "last_run":{"id":7,"task":"analyze","scheduled_for":"2026-08-31T10:00:00Z",
         "started_at":"2026-08-31T10:00:08.842399834Z",
         "finished_at":"2026-08-31T10:03:00.5Z","exit_code":0,"outcome":"on_time",
         "log_path":"/data/logs/analyze/x.log"}},
      {"name":"batch","enabled":true,"watermark":"30m0s",
       "next_expected_run":{"kind":"after_success"},
       "running":{"scheduled_for":"2026-08-31T10:00:00Z",
         "started_at":"2026-08-31T10:00:05Z","elapsed_seconds":74}},
      {"name":"overdue","enabled":true,"cron":"0 * * * *","overlap":"queue-one","catch_up":true,
       "next_fire":"2026-08-31T11:00:00Z",
       "next_expected_run":{"kind":"after_current"},
       "running":{"scheduled_for":"2026-08-31T09:00:00Z",
         "started_at":"2026-08-31T09:00:05Z","elapsed_seconds":4200},
       "queued_for":"2026-08-31T10:00:00Z","overrun_seconds":712},
      {"name":"held","enabled":true,"paused":true,"cron":"@daily",
       "next_expected_run":{"kind":"none"}}
    ]}
    """

    func testStatusDecodes() throws {
        let tasks = try CLIDecode.statusTasks(from: Data(statusJSON.utf8))
        XCTAssertEqual(tasks.count, 4)
        XCTAssertEqual(tasks[0].name, "analyze")
        XCTAssertEqual(tasks[0].lastRun?.exitCode, 0)
        XCTAssertNotNil(tasks[0].lastRun?.finishedAt, "fractional-second timestamps must parse")
        XCTAssertEqual(tasks[1].watermark, "30m0s")
        XCTAssertEqual(tasks[2].overrunSeconds, 712)
        XCTAssertTrue(tasks[3].paused)
    }

    func testStatusToleratesUnknownEnumValues() throws {
        // The CLI owns the vocabulary; a new kind must not break decoding.
        let json = """
        {"tasks":[{"name":"x","enabled":true,
          "next_expected_run":{"kind":"some_future_kind"}}]}
        """
        let tasks = try CLIDecode.statusTasks(from: Data(json.utf8))
        XCTAssertEqual(tasks[0].nextExpectedRun.kind, "some_future_kind")
    }

    func testEmptyAndNullTolerated() throws {
        XCTAssertEqual(try CLIDecode.statusTasks(from: Data("{}".utf8)), [])
        XCTAssertEqual(try CLIDecode.historyRuns(from: Data(#"{"task":"a","runs":null}"#.utf8)), [])
    }
}

final class StateMappingTests: XCTestCase {
    private func date(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: s)!
    }

    func testDisplayStateSeverity() {
        XCTAssertEqual(displayState(for: TaskView(name: "a", enabled: false)), .disabled)
        XCTAssertEqual(displayState(for: TaskView(name: "a", paused: true)), .paused)
        XCTAssertEqual(displayState(for: TaskView(name: "a")), .idle)
        let running = TaskView(
            name: "a",
            running: RunningStatus(scheduledFor: Date(), startedAt: Date(), elapsedSeconds: 5))
        XCTAssertEqual(displayState(for: running), .running)
        var overrun = running
        overrun.overrunSeconds = 90
        XCTAssertEqual(displayState(for: overrun), .overrun)
        XCTAssertTrue(TaskDisplayState.overrun > .running)
    }

    func testMenuBarQuietWhenHealthy() {
        let summary = menuBarSummary(tasks: [TaskView(name: "a")], daemonUp: true)
        XCTAssertEqual(summary.symbolName, "clock")
        XCTAssertNil(summary.text, "the bar stays quiet in the normal case")
    }

    func testMenuBarSpeaksOnOverrun() {
        var t = TaskView(
            name: "a",
            running: RunningStatus(scheduledFor: Date(), startedAt: Date(), elapsedSeconds: 100))
        t.overrunSeconds = 720
        let summary = menuBarSummary(tasks: [t], daemonUp: true)
        XCTAssertEqual(summary.symbolName, "clock.badge.exclamationmark")
        XCTAssertEqual(summary.text, "12m")
    }

    func testMenuBarDaemonDownIsDistinct() {
        let summary = menuBarSummary(tasks: [], daemonUp: false)
        XCTAssertEqual(summary.symbolName, "clock.badge.questionmark")
    }

    func testCompactDuration() {
        XCTAssertEqual(compactDuration(42), "42s")
        XCTAssertEqual(compactDuration(720), "12m")
        XCTAssertEqual(compactDuration(5520), "1h32m")
        XCTAssertEqual(compactDuration(3600), "1h")
    }

    func testOverrunStateTextIsExplicitWord() {
        let now = date("2026-08-31T10:12:00Z")
        var t = TaskView(
            name: "a",
            running: RunningStatus(
                scheduledFor: date("2026-08-31T09:00:00Z"),
                startedAt: date("2026-08-31T09:30:00Z"),
                elapsedSeconds: 0))
        t.overrunSeconds = 720
        let text = taskRowText(t, now: now)
        XCTAssertTrue(text.state.contains("overrun 12m"), "got: \(text.state)")
        XCTAssertFalse(text.state.contains("-12"), "never a negative countdown")
    }

    func testNextRunKinds() {
        let now = date("2026-08-31T10:00:00Z")
        var atTask = TaskView(name: "a")
        atTask.nextExpectedRun = NextExpected(kind: "at", at: date("2026-08-31T10:30:00Z"))
        XCTAssertTrue(taskRowText(atTask, now: now).nextRun.hasPrefix("in 30m"))

        var after = TaskView(name: "a")
        after.nextExpectedRun = NextExpected(kind: "after_current", at: nil)
        XCTAssertEqual(taskRowText(after, now: now).nextRun, "after current run")

        var wm = TaskView(name: "a", watermark: "30m0s")
        wm.nextExpectedRun = NextExpected(kind: "after_success", at: nil)
        XCTAssertEqual(taskRowText(wm, now: now).nextRun, "on success + 30m0s")
        XCTAssertEqual(taskRowText(wm, now: now).trigger, "success + 30m0s")
    }

    func testLastRunText() {
        let sched = date("2026-08-31T09:00:00Z")
        let ok = Run(id: 1, task: "a", scheduledFor: sched, startedAt: sched,
                     finishedAt: sched.addingTimeInterval(60), exitCode: 0, outcome: "on_time")
        var t = TaskView(name: "a", lastRun: ok)
        XCTAssertTrue(lastRunText(t).hasPrefix("ok "))

        let failed = Run(id: 2, task: "a", scheduledFor: sched, startedAt: sched,
                         finishedAt: sched.addingTimeInterval(60), exitCode: 3, outcome: "on_time")
        t.lastRun = failed
        XCTAssertTrue(lastRunText(t).hasPrefix("exit 3 "))

        let missed = Run(id: 3, task: "a", scheduledFor: sched, outcome: "missed", missedReason: "overlap")
        t.lastRun = missed
        XCTAssertTrue(lastRunText(t).hasPrefix("missed(overlap)"))

        t.lastRun = nil
        XCTAssertEqual(lastRunText(t), "—")
    }
}

final class PopoverLayoutTests: XCTestCase {
    func testHeightFloorAndCap() {
        XCTAssertEqual(PopoverLayout.contentHeight(rows: 0), PopoverLayout.minHeight)
        XCTAssertEqual(PopoverLayout.contentHeight(rows: 2), 2 * PopoverLayout.rowHeight)
        XCTAssertEqual(PopoverLayout.contentHeight(rows: 100), PopoverLayout.maxHeight)
        XCTAssertGreaterThan(PopoverLayout.contentHeight(rows: 1), 0, "must never collapse to zero")
    }
}

final class SingleInstanceTests: XCTestCase {
    func testBareBinaryProceeds() {
        XCTAssertEqual(singleInstanceDecision(bundleID: nil, ownPID: 1, instancePIDs: []), .proceed)
    }

    func testSoleInstanceProceeds() {
        XCTAssertEqual(
            singleInstanceDecision(bundleID: "jp.nlink.task-clock-gui", ownPID: 42, instancePIDs: [42]),
            .proceed)
    }

    func testDuplicateExits() {
        let decision = singleInstanceDecision(
            bundleID: "jp.nlink.task-clock-gui", ownPID: 42, instancePIDs: [42, 99])
        guard case .exitDuplicate(let message) = decision else {
            return XCTFail("expected exitDuplicate, got \(decision)")
        }
        XCTAssertTrue(message.contains("99"))
    }
}

final class LoginFeedbackTests: XCTestCase {
    func testSilentWhenStateMatchesRequest() {
        XCTAssertNil(loginItemFeedback(requested: true, nowEnabled: true))
        XCTAssertNil(loginItemFeedback(requested: false, nowEnabled: false))
    }

    func testSpeaksWhenTheSwitchSnappedBack() {
        // "No error but nothing happened" must never pass silently.
        let enableFailed = loginItemFeedback(requested: true, nowEnabled: false)
        XCTAssertNotNil(enableFailed)
        XCTAssertTrue(enableFailed!.contains("System Settings"))
        XCTAssertNotNil(loginItemFeedback(requested: false, nowEnabled: true))
    }
}

final class TransitionEventTests: XCTestCase {
    private func running(_ name: String, overrun: Double) -> TaskView {
        var t = TaskView(
            name: name,
            running: RunningStatus(scheduledFor: Date(), startedAt: Date(), elapsedSeconds: 60))
        t.overrunSeconds = overrun
        return t
    }

    func testDaemonDownFiresOnceOnTransition() {
        let down = transitionEvents(oldTasks: [], newTasks: [], wasDaemonUp: true, isDaemonUp: false)
        XCTAssertEqual(down.map(\.id), ["daemon-down"])
        let stillDown = transitionEvents(oldTasks: [], newTasks: [], wasDaemonUp: false, isDaemonUp: false)
        XCTAssertTrue(stillDown.isEmpty, "edge-triggered: no repeat while it stays down")
    }

    func testOverrunEntryFiresOnceAndSuppressesWhilePersisting() {
        let before = running("a", overrun: 0)
        let entered = running("a", overrun: 90)
        let events = transitionEvents(
            oldTasks: [before], newTasks: [entered], wasDaemonUp: true, isDaemonUp: true)
        XCTAssertEqual(events.map(\.id), ["overrun-a"])

        let persisting = transitionEvents(
            oldTasks: [entered], newTasks: [running("a", overrun: 150)],
            wasDaemonUp: true, isDaemonUp: true)
        XCTAssertTrue(persisting.isEmpty)
    }

    func testFailureFiresForNewFailedRunOnly() {
        let sched = Date()
        let failed = Run(id: 9, task: "a", scheduledFor: sched, startedAt: sched,
                         finishedAt: sched, exitCode: 3, outcome: "on_time")
        let before = TaskView(name: "a")
        let after = TaskView(name: "a", lastRun: failed)
        let events = transitionEvents(
            oldTasks: [before], newTasks: [after], wasDaemonUp: true, isDaemonUp: true)
        XCTAssertEqual(events.map(\.id), ["failure-a-9"])

        // Same run seen again: no repeat. A later successful run: nothing.
        XCTAssertTrue(transitionEvents(
            oldTasks: [after], newTasks: [after], wasDaemonUp: true, isDaemonUp: true).isEmpty)
        let ok = Run(id: 10, task: "a", scheduledFor: sched, startedAt: sched,
                     finishedAt: sched, exitCode: 0, outcome: "on_time")
        var recovered = after
        recovered.lastRun = ok
        XCTAssertTrue(transitionEvents(
            oldTasks: [after], newTasks: [recovered], wasDaemonUp: true, isDaemonUp: true).isEmpty)
    }

    func testUnknownPreviousTaskStaysQuiet() {
        // A task first seen in this snapshot (fresh launch, reload) must not
        // fire from its launch-time state.
        let events = transitionEvents(
            oldTasks: [], newTasks: [running("new", overrun: 300)],
            wasDaemonUp: true, isDaemonUp: true)
        XCTAssertTrue(events.isEmpty)
    }
}

final class DaemonLampTests: XCTestCase {
    func testLampShowsActualStateIndependentOfSwitch() {
        // Running wins regardless of registration (foreground serve counts).
        XCTAssertEqual(daemonLamp(installed: true, up: true), .running)
        XCTAssertEqual(daemonLamp(installed: false, up: true), .running)
        // ON switch + dead daemon = the distinct "stalled" state.
        XCTAssertEqual(daemonLamp(installed: true, up: false), .stalled)
        XCTAssertEqual(daemonLamp(installed: false, up: false), .stopped)
    }

    func testLampTextsAreDistinct() {
        let texts = [DaemonLampState.running, .stalled, .stopped].map(daemonLampText)
        XCTAssertEqual(Set(texts).count, 3)
    }
}

final class DaemonInstallTests: XCTestCase {
    func testPlistPath() {
        XCTAssertEqual(
            daemonPlistPath(home: "/Users/x"),
            "/Users/x/Library/LaunchAgents/jp.nlink.task-clock.plist")
    }

    func testFeedbackSilentOnMatch() {
        XCTAssertNil(daemonInstallFeedback(requested: true, installedNow: true))
        XCTAssertNil(daemonInstallFeedback(requested: false, installedNow: false))
    }

    func testFeedbackSpeaksOnMismatch() {
        XCTAssertNotNil(daemonInstallFeedback(requested: true, installedNow: false))
        XCTAssertNotNil(daemonInstallFeedback(requested: false, installedNow: true))
    }
}

final class BinaryResolutionTests: XCTestCase {
    func testBundledWinsInRelease() {
        let path = resolveCLIBinary(
            env: ["TASK_CLOCK_GUI_BIN": "/env/task-clock"],
            allowEnvOverride: false,
            bundled: "/app/Resources/task-clock",
            devPaths: ["/dev/task-clock"],
            isExecutable: { _ in true })
        XCTAssertEqual(path, "/app/Resources/task-clock",
                       "release builds must not honor the env override")
    }

    func testEnvOverrideOnlyInDebug() {
        let path = resolveCLIBinary(
            env: ["TASK_CLOCK_GUI_BIN": "/env/task-clock"],
            allowEnvOverride: true,
            bundled: "/app/Resources/task-clock",
            devPaths: [],
            isExecutable: { _ in true })
        XCTAssertEqual(path, "/env/task-clock")
    }

    func testFallsThroughToBrewThenDev() {
        let path = resolveCLIBinary(
            env: [:],
            allowEnvOverride: false,
            bundled: "/app/Resources/task-clock",
            devPaths: ["/dev/task-clock"],
            isExecutable: { $0 == "/dev/task-clock" })
        XCTAssertEqual(path, "/dev/task-clock")
    }

    func testNilWhenNothingExecutable() {
        XCTAssertNil(resolveCLIBinary(
            env: [:], allowEnvOverride: false, bundled: nil, devPaths: [],
            isExecutable: { _ in false }))
    }
}
