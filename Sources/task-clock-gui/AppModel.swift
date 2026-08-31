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
    @Published var launchAtLogin = false
    /// Whether the task-clock LaunchAgent is registered (plist present) —
    /// distinct from daemonUp: a foreground `serve` is up but not installed.
    @Published var daemonInstalled = false

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
        launchAtLogin = LoginItem.isEnabled
        refresh()
    }

    func popoverOpened() {
        reschedule(interval: Self.foregroundInterval)
        // Re-read: the user can flip this in System Settings behind our back.
        launchAtLogin = LoginItem.isEnabled
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

    /// Whether a snapshot has been applied since launch — transition
    /// banners need a real "before", or launch-time states fire stale ones.
    private var hasSnapshot = false

    private func apply(_ outcome: Result<[TaskView], Error>) {
        let oldTasks = tasks
        let wasDaemonUp = daemonUp
        defer {
            if hasSnapshot {
                // daemonInstalled is re-read below before this defer runs,
                // so a deliberate stop (registration removed) stays silent.
                Notifier.shared.post(transitionEvents(
                    oldTasks: oldTasks, newTasks: tasks,
                    wasDaemonUp: wasDaemonUp, isDaemonUp: daemonUp,
                    installedNow: daemonInstalled))
            }
            hasSnapshot = true
        }
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
        self.daemonInstalled = FileManager.default.fileExists(
            atPath: daemonPlistPath(home: NSHomeDirectory()))
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

    // MARK: - Daemon lifecycle

    func setDaemonInstalled(_ requested: Bool) {
        Task.detached(priority: .userInitiated) { [weak self] in
            var failure: String?
            do {
                if requested {
                    try CLIRunner.installDaemon()
                } else {
                    try CLIRunner.uninstallDaemon()
                }
            } catch {
                failure = error.localizedDescription
            }
            let installedNow = FileManager.default.fileExists(
                atPath: daemonPlistPath(home: NSHomeDirectory()))
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.daemonInstalled = installedNow
                if let failure {
                    self.lastError = failure
                } else if let feedback = daemonInstallFeedback(
                    requested: requested, installedNow: installedNow) {
                    self.lastError = feedback
                }
            }
            // Give launchd a moment to start/stop the daemon, then re-poll.
            try? await Task.sleep(for: .seconds(1))
            await self?.refresh()
        }
    }

    // MARK: - Launch at login

    var loginItemAvailable: Bool { LoginItem.isAvailable }

    func setLaunchAtLogin(_ requested: Bool) {
        do {
            try LoginItem.setEnabled(requested)
        } catch {
            lastError = "Launch at login: \(error.localizedDescription)"
        }
        // Report the state that actually took effect, never the request —
        // and when they differ without an error, say so (requiresApproval).
        launchAtLogin = LoginItem.isEnabled
        if lastError == nil, let feedback = loginItemFeedback(
            requested: requested, nowEnabled: launchAtLogin) {
            lastError = feedback
        }
    }
}
