import Foundation
import TaskClockGUICore

/// Polls the daemon (through the CLI) and holds the displayed state.
@MainActor
final class AppModel: ObservableObject {
    @Published var tasks: [TaskView] = []
    @Published var daemonUp = false
    /// Human-readable problem from the last poll or action; nil when healthy.
    /// Shown in the popover itself — errors must surface where the user acts.
    @Published var lastError: String?
    @Published var lastUpdated: Date?

    private var timer: Timer?
    private var activity: NSObjectProtocol?

    /// Foreground (popover open) polls fast; background keeps the menu-bar
    /// symbol honest without burning CPU.
    static let backgroundInterval: TimeInterval = 30
    static let foregroundInterval: TimeInterval = 5

    func start() {
        // Opt out of App Nap: a napped timer freezes the poll and the
        // menu-bar state silently goes stale (org lesson: sensor-lens-gui).
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep],
                reason: "task-clock daemon polling")
        }
        reschedule(interval: Self.backgroundInterval)
        refresh()
    }

    func popoverOpened() {
        reschedule(interval: Self.foregroundInterval)
        refresh()
    }

    func popoverClosed() {
        reschedule(interval: Self.backgroundInterval)
    }

    private func reschedule(interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // .common keeps it firing while menus/popovers hold the run loop.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        Task.detached(priority: .utility) { [weak self] in
            let outcome: Result<[TaskView], Error>
            do {
                outcome = .success(try CLIRunner.status())
            } catch {
                outcome = .failure(error)
            }
            await MainActor.run { [weak self] in
                self?.apply(outcome)
            }
        }
    }

    private func apply(_ outcome: Result<[TaskView], Error>) {
        switch outcome {
        case .success(let tasks):
            self.tasks = tasks
            self.daemonUp = true
            self.lastError = nil
            self.lastUpdated = Date()
        case .failure(let error):
            if case CLIError.daemonDown = error {
                self.daemonUp = false
                self.lastError = nil // a distinct state, not an error banner
            } else {
                self.lastError = error.localizedDescription
            }
            self.lastUpdated = Date()
        }
    }

    // MARK: - Actions
    //
    // Actions run the CLI off the main thread, then re-poll so the popover
    // reflects the daemon's actual state — never an optimistic local guess.
    // Failures land in lastError, visible in the same popover the user
    // clicked in.

    func trigger(task: String) { act { try CLIRunner.trigger(task: task) } }
    func pause(task: String) { act { try CLIRunner.pause(task: task) } }
    func resume(task: String) { act { try CLIRunner.resume(task: task) } }
    func reload() { act { try CLIRunner.reload() } }

    private func act(_ body: @escaping @Sendable () throws -> Void) {
        Task.detached(priority: .userInitiated) { [weak self] in
            var failure: String?
            do {
                try body()
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run { [weak self] in
                if let failure {
                    self?.lastError = failure
                }
            }
            await self?.refresh()
        }
    }

    var menuBar: MenuBarSummary {
        menuBarSummary(tasks: tasks, daemonUp: daemonUp)
    }
}
