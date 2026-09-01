import AppKit
import XCTest
@testable import TaskClockGUICore

final class SymbolResolutionTests: XCTestCase {
    // A plausible-but-fake SF Symbol name fails neither compile nor
    // runtime — it renders blank. Every emit-able name must resolve.
    func testEveryInventorySymbolResolves() {
        for name in Symbols.all {
            XCTAssertNotNil(
                NSImage(systemSymbolName: name, accessibilityDescription: nil),
                "SF Symbol does not exist: \(name)")
        }
    }

    // The menu-bar summaries must only ever emit inventoried names.
    func testMenuBarSummariesEmitInventoriedSymbols() {
        let running = TaskView(
            name: "a",
            running: RunningStatus(scheduledFor: Date(), startedAt: Date(), elapsedSeconds: 5))
        var overrun = running
        overrun.overrunSeconds = 90
        let summaries = [
            menuBarSummary(tasks: [], daemonUp: false),
            menuBarSummary(tasks: [TaskView(name: "a")], daemonUp: true),
            menuBarSummary(tasks: [running], daemonUp: true),
            menuBarSummary(tasks: [overrun], daemonUp: true),
        ]
        for summary in summaries {
            XCTAssertTrue(Symbols.all.contains(summary.symbolName),
                          "menu bar emits uninventoried symbol: \(summary.symbolName)")
        }
    }
}

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

    func testRowIndicatorColorGrammar() {
        // Gray means deliberately off — never "healthy but idle".
        XCTAssertEqual(rowIndicator(for: TaskView(name: "a", enabled: false)), .disabled)
        XCTAssertEqual(rowIndicator(for: TaskView(name: "a", paused: true)), .paused)
        // A healthy scheduled task is green even while idle.
        XCTAssertEqual(rowIndicator(for: TaskView(name: "a")), .healthy)

        let sched = Date()
        let okRun = Run(id: 1, task: "a", scheduledFor: sched, startedAt: sched,
                        finishedAt: sched, exitCode: 0, outcome: "on_time")
        XCTAssertEqual(rowIndicator(for: TaskView(name: "a", lastRun: okRun)), .healthy)

        let failedRun = Run(id: 2, task: "a", scheduledFor: sched, startedAt: sched,
                            finishedAt: sched, exitCode: 3, outcome: "on_time")
        XCTAssertEqual(rowIndicator(for: TaskView(name: "a", lastRun: failedRun)), .failed)

        let missedRun = Run(id: 3, task: "a", scheduledFor: sched,
                            outcome: "missed", missedReason: "overlap")
        XCTAssertEqual(rowIndicator(for: TaskView(name: "a", lastRun: missedRun)), .missedLast)

        // Running (recovering) outranks a bad last run; switch-off outranks both.
        var runningAfterFailure = TaskView(name: "a", lastRun: failedRun)
        runningAfterFailure.running = RunningStatus(
            scheduledFor: sched, startedAt: sched, elapsedSeconds: 5)
        XCTAssertEqual(rowIndicator(for: runningAfterFailure), .running)
        let pausedAfterFailure = TaskView(name: "a", paused: true, lastRun: failedRun)
        XCTAssertEqual(rowIndicator(for: pausedAfterFailure), .paused)
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

        // A fire time the poll has not caught up with yet reads "due now" —
        // the honest gap state while the per-second display outruns the
        // 5-second poll.
        var due = TaskView(name: "a")
        due.nextExpectedRun = NextExpected(kind: "at", at: date("2026-08-31T09:59:58Z"))
        XCTAssertTrue(taskRowText(due, now: now).nextRun.hasPrefix("due now"))

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

final class HistoryRowTests: XCTestCase {
    private let sched = ISO8601DateFormatter().date(from: "2026-08-31T12:04:00Z")!

    func testOkRun() {
        let run = Run(id: 1, task: "a", scheduledFor: sched,
                      startedAt: sched.addingTimeInterval(8),
                      finishedAt: sched.addingTimeInterval(9), exitCode: 0, outcome: "on_time")
        let text = runRowText(run)
        XCTAssertEqual(text.startDelay, "+8s")
        XCTAssertEqual(text.duration, "1s")
        XCTAssertEqual(text.result, "ok")
        XCTAssertEqual(runRowIndicator(for: run), .healthy)
    }

    func testSubSecondStartHidesDelay() {
        let run = Run(id: 1, task: "a", scheduledFor: sched,
                      startedAt: sched.addingTimeInterval(0.4),
                      finishedAt: sched.addingTimeInterval(2), exitCode: 0, outcome: "on_time")
        XCTAssertEqual(runRowText(run).startDelay, "")
    }

    func testQueuedAndManualOutcomesAnnotated() {
        let queued = Run(id: 2, task: "a", scheduledFor: sched,
                         startedAt: sched.addingTimeInterval(90),
                         finishedAt: sched.addingTimeInterval(95), exitCode: 0, outcome: "queued")
        XCTAssertEqual(runRowText(queued).result, "ok (queued)")
        let manual = Run(id: 3, task: "a", scheduledFor: sched,
                         startedAt: sched, finishedAt: sched.addingTimeInterval(1),
                         exitCode: 3, outcome: "manual")
        XCTAssertEqual(runRowText(manual).result, "exit 3 (manual)")
        XCTAssertEqual(runRowIndicator(for: manual), .failed)
    }

    func testMissedRun() {
        let run = Run(id: 4, task: "a", scheduledFor: sched, outcome: "missed", missedReason: "overlap")
        let text = runRowText(run)
        XCTAssertEqual(text.startDelay, "—")
        XCTAssertEqual(text.duration, "—")
        XCTAssertEqual(text.result, "missed(overlap)")
        XCTAssertEqual(runRowIndicator(for: run), .missedLast)
    }

    func testRunningRun() {
        let run = Run(id: 5, task: "a", scheduledFor: sched,
                      startedAt: sched.addingTimeInterval(5), outcome: "on_time")
        let text = runRowText(run)
        XCTAssertEqual(text.duration, "running")
        XCTAssertEqual(text.result, "running")
        XCTAssertEqual(runRowIndicator(for: run), .running)
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

    func testDaemonDownFiresOnceOnTransitionWhileInstalled() {
        let down = transitionEvents(
            oldTasks: [], newTasks: [], wasDaemonUp: true, isDaemonUp: false, intendedUp: true)
        XCTAssertEqual(down.map(\.id), ["daemon-down"])
        let stillDown = transitionEvents(
            oldTasks: [], newTasks: [], wasDaemonUp: false, isDaemonUp: false, intendedUp: true)
        XCTAssertTrue(stillDown.isEmpty, "edge-triggered: no repeat while it stays down")
    }

    func testDeliberateStopStaysSilent() {
        // The user flipped the power switch off (`task-clock stop`
        // disables the service; uninstall deregisters it) — either way the
        // intent is gone, and an intentional stop is not an incident.
        let events = transitionEvents(
            oldTasks: [], newTasks: [], wasDaemonUp: true, isDaemonUp: false, intendedUp: false)
        XCTAssertTrue(events.isEmpty, "self-inflicted stop must not notify")
    }

    func testOverrunEntryFiresOnceAndSuppressesWhilePersisting() {
        let before = running("a", overrun: 0)
        let entered = running("a", overrun: 90)
        let events = transitionEvents(
            oldTasks: [before], newTasks: [entered], wasDaemonUp: true, isDaemonUp: true, intendedUp: true)
        XCTAssertEqual(events.map(\.id), ["overrun-a"])

        let persisting = transitionEvents(
            oldTasks: [entered], newTasks: [running("a", overrun: 150)],
            wasDaemonUp: true, isDaemonUp: true, intendedUp: true)
        XCTAssertTrue(persisting.isEmpty)
    }

    func testFailureFiresForNewFailedRunOnly() {
        let sched = Date()
        let failed = Run(id: 9, task: "a", scheduledFor: sched, startedAt: sched,
                         finishedAt: sched, exitCode: 3, outcome: "on_time")
        let before = TaskView(name: "a")
        let after = TaskView(name: "a", lastRun: failed)
        let events = transitionEvents(
            oldTasks: [before], newTasks: [after], wasDaemonUp: true, isDaemonUp: true, intendedUp: true)
        XCTAssertEqual(events.map(\.id), ["failure-a-9"])

        // Same run seen again: no repeat. A later successful run: nothing.
        XCTAssertTrue(transitionEvents(
            oldTasks: [after], newTasks: [after], wasDaemonUp: true, isDaemonUp: true, intendedUp: true).isEmpty)
        let ok = Run(id: 10, task: "a", scheduledFor: sched, startedAt: sched,
                     finishedAt: sched, exitCode: 0, outcome: "on_time")
        var recovered = after
        recovered.lastRun = ok
        XCTAssertTrue(transitionEvents(
            oldTasks: [after], newTasks: [recovered], wasDaemonUp: true, isDaemonUp: true, intendedUp: true).isEmpty)
    }

    func testAdoptedRunReadsUnmanaged() {
        // The stop/start power switch creates adopted runs — the row must
        // say so, because their exit status will be unknowable.
        let t = TaskView(
            name: "a",
            running: RunningStatus(scheduledFor: Date(), startedAt: Date(), elapsedSeconds: 60),
            releasedUnmanaged: true)
        XCTAssertTrue(taskRowText(t, now: Date()).state.contains("running (unmanaged)"))
    }

    func testFailureFiresWhenTheSameRunTransitionsOpenToFailed() {
        // Any run longer than one poll interval is seen OPEN first, then
        // finished under the SAME id — a new-id check alone silences all
        // of them (verification finding).
        let sched = Date()
        let open = Run(id: 9, task: "a", scheduledFor: sched, startedAt: sched,
                       finishedAt: nil, exitCode: nil, outcome: "on_time")
        let failed = Run(id: 9, task: "a", scheduledFor: sched, startedAt: sched,
                         finishedAt: sched, exitCode: 3, outcome: "on_time")
        let events = transitionEvents(
            oldTasks: [TaskView(name: "a", lastRun: open)],
            newTasks: [TaskView(name: "a", lastRun: failed)],
            wasDaemonUp: true, isDaemonUp: true, intendedUp: true)
        XCTAssertEqual(events.map(\.id), ["failure-a-9"])
    }

    func testUnknownExitIsNotAFailure() {
        // An adopted run's finalization has NO exit code (unknowable ≠
        // failed) — it must never raise the failure banner.
        let sched = Date()
        let open = Run(id: 9, task: "a", scheduledFor: sched, startedAt: sched,
                       finishedAt: nil, exitCode: nil, outcome: "on_time")
        let unknown = Run(id: 9, task: "a", scheduledFor: sched, startedAt: sched,
                          finishedAt: sched, exitCode: nil, outcome: "on_time",
                          error: "released run ended (exit status unknown)")
        let events = transitionEvents(
            oldTasks: [TaskView(name: "a", lastRun: open)],
            newTasks: [TaskView(name: "a", lastRun: unknown)],
            wasDaemonUp: true, isDaemonUp: true, intendedUp: true)
        XCTAssertTrue(events.isEmpty, "unknown exit notified as failure")
    }

    func testUnknownPreviousTaskStaysQuiet() {
        // A task first seen in this snapshot (fresh launch, reload) must not
        // fire from its launch-time state.
        let events = transitionEvents(
            oldTasks: [], newTasks: [running("new", overrun: 300)],
            wasDaemonUp: true, isDaemonUp: true, intendedUp: true)
        XCTAssertTrue(events.isEmpty)
    }
}

final class DaemonLampTests: XCTestCase {
    func testLampShowsActualStateIndependentOfSwitch() {
        // Running wins regardless of registration (foreground serve counts).
        XCTAssertEqual(daemonLamp(installed: true, enabled: true, up: true), .running)
        XCTAssertEqual(daemonLamp(installed: false, enabled: true, up: true), .running)
        // ON switch + dead daemon = the distinct "stalled" state.
        XCTAssertEqual(daemonLamp(installed: true, enabled: true, up: false), .stalled)
        // Deliberately stopped (disabled) is NOT stalled — no repair hint,
        // no anomaly color; the user chose this state.
        XCTAssertEqual(daemonLamp(installed: true, enabled: false, up: false), .stopped)
        // Never set up at all: its own state, with its own prompt.
        XCTAssertEqual(daemonLamp(installed: false, enabled: true, up: false), .notInstalled)
        XCTAssertEqual(daemonLamp(installed: false, enabled: false, up: false), .notInstalled)
    }

    func testLampTextsAreDistinct() {
        let texts = [DaemonLampState.running, .stalled, .stopped, .notInstalled].map(daemonLampText)
        XCTAssertEqual(Set(texts).count, 4)
    }
}

final class DaemonRunStateTests: XCTestCase {
    func testRunFeedbackSilentOnMatchSpeaksOnMismatch() {
        XCTAssertNil(daemonRunFeedback(requested: true, enabledNow: true))
        XCTAssertNil(daemonRunFeedback(requested: false, enabledNow: false))
        XCTAssertNotNil(daemonRunFeedback(requested: true, enabledNow: false))
        XCTAssertNotNil(daemonRunFeedback(requested: false, enabledNow: true))
    }

    func testEnabledParsesModernDisableDump() {
        let dump = """
        disabled services = {
        \t"com.apple.example" => enabled
        \t"jp.nlink.task-clock" => disabled
        }
        """
        XCTAssertFalse(daemonEnabledInDump(dump))
    }

    func testEnabledParsesLegacyTrueMeansDisabled() {
        XCTAssertFalse(daemonEnabledInDump("\t\"jp.nlink.task-clock\" => true\n"))
    }

    func testEnabledWhenAbsentOrExplicitlyEnabled() {
        // Absent from the dump = launchd's default = enabled; an unreadable
        // dump must not invent a deliberate stop (it would mute the
        // daemon-down notification).
        XCTAssertTrue(daemonEnabledInDump(""))
        XCTAssertTrue(daemonEnabledInDump("disabled services = {\n}\n"))
        XCTAssertTrue(daemonEnabledInDump("\t\"jp.nlink.task-clock\" => enabled\n"))
        // A different label's disable is not ours.
        XCTAssertTrue(daemonEnabledInDump("\t\"jp.nlink.task-clock-gui\" => disabled\n"))
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
