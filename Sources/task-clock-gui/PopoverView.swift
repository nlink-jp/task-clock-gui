import SwiftUI
import TaskClockGUICore

struct PopoverView: View {
    @ObservedObject var model: AppModel

    /// Uninstall interlock (same shape as run-now): first click arms,
    /// second click within the window fires, the arm decays on its own. A
    /// setup-destroying action must not ride on a single stray click.
    @State private var uninstallArmed = false
    @State private var uninstallDisarm: Task<Void, Never>?

    // Hosted in a resizable NSPanel: the window supplies the size, the
    // content fills it. No fixedSize, no width constant, no height caps —
    // those belonged to the MenuBarExtra era, where the window tracked the
    // content's ideal size.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if let error = model.lastError {
                Divider()
                Label(error, systemImage: Symbols.errorLabel)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
                    .padding(8)
            }
            Divider()
            footer
        }
        .frame(minWidth: 340, maxWidth: .infinity, minHeight: 280, maxHeight: .infinity)
    }

    /// Title line carries the daemon pilot lamp + power switch
    /// (load-spinner's header pattern): the lamp shows the actual state,
    /// the switch holds the *run intent* — start/stop only, never
    /// install/uninstall (user feedback: one switch for both meant
    /// uninstalling to pause; setup lives in the footer and the
    /// not-installed prompt). An ON switch with an orange lamp is
    /// precisely "should be running but isn't answering" — Restart is its
    /// repair path. No manual refresh button: the popover auto-polls
    /// every 5 s and every action re-polls; the timestamp shows the
    /// freshness instead.
    private var header: some View {
        let lamp = daemonLamp(
            installed: model.daemonInstalled,
            enabled: model.daemonEnabled,
            up: model.daemonUp)
        return HStack(spacing: 6) {
            Text("task-clock").font(.headline)
            Circle()
                .fill(lampColor(lamp))
                .frame(width: 7, height: 7)
                .help(daemonLampText(lamp))
            Text(lampCaption(lamp))
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.daemonInstalled {
                Toggle("", isOn: Binding(
                    get: { model.daemonEnabled },
                    set: { model.setDaemonRunning($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .focusable(false)
                .help("Power: start / stop the daemon. Stopping never kills running tasks; they are picked up again on start.")
            }
            if lamp == .stalled {
                Button("Restart") { model.setDaemonInstalled(true) }
                    .controlSize(.small)
                    .focusable(false)
                    .help("Re-register the launch agent (task-clock install)")
            }
            Spacer()
            if let updated = model.lastUpdated {
                Text("as of \(updated, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
    }

    private func lampCaption(_ state: DaemonLampState) -> String {
        switch state {
        case .running: return "running"
        case .stalled: return "not responding"
        case .stopped: return "stopped"
        case .notInstalled: return "not installed"
        }
    }

    private func lampColor(_ state: DaemonLampState) -> Color {
        switch state {
        case .running: return .green
        case .stalled: return .orange
        case .stopped, .notInstalled: return Color(nsColor: .tertiaryLabelColor)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let task = model.historyTask {
            HistoryView(model: model, taskName: task)
        } else if !model.daemonUp {
            daemonDown
        } else if model.tasks.isEmpty {
            VStack(spacing: 6) {
                Text("No tasks defined").font(.callout)
                Text("Add [[task]] files under ~/.config/task-clock/tasks.d/ and reload.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            // The daemon is polled every 5 s, but countdowns ("in 3s") and
            // elapsed times are *derived* from timestamps — recompute them
            // every second locally via TimelineView, or the text freezes
            // between polls and jumps. Once a fire time passes and the poll
            // has not caught up yet, the row honestly reads "due now".
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.tasks, id: \.name) { task in
                            TaskRow(task: task, model: model, now: timeline.date)
                            if task.name != model.tasks.last?.name {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var daemonDown: some View {
        if !model.daemonInstalled {
            // Setup lives here, not on the power switch: installing is a
            // one-time action, deliberately separate from the daily
            // start/stop control.
            VStack(alignment: .leading, spacing: 8) {
                Text("task-clock runs as a background daemon. Install its launch agent to get started — it runs now and at every login.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Install daemon") { model.setDaemonInstalled(true) }
                    .controlSize(.small)
                    .focusable(false)
                    .help("Register the launch agent (task-clock install)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        } else {
            Text(model.daemonEnabled
                ? "The daemon should be running but is not answering — it may still be starting, or its config may be invalid (try Restart above; `task-clock validate` diagnoses config problems)."
                : "The daemon is stopped. Tasks are not being scheduled; flip the switch above to start it. Any still-running task keeps running and is picked up again on start.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if model.notificationsDenied {
                // Banners are a shipped behavior that can be permanently,
                // silently dead — the screen is this app's only channel,
                // so a hard denial is stated where the user acts.
                HStack(spacing: 4) {
                    Text("Notifications are off for TaskClock.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                    .focusable(false)
                    Spacer()
                }
            }
            if model.loginItemAvailable || model.daemonInstalled {
                HStack {
                    if model.loginItemAvailable {
                        Toggle("Launch at login", isOn: Binding(
                            get: { model.launchAtLogin },
                            set: { model.setLaunchAtLogin($0) }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .focusable(false)
                        .help("Open this menu-bar app when you log in")
                    }
                    Spacer()
                    if model.daemonInstalled {
                        // Setup-level counterpart of the Install button in
                        // the not-installed prompt; deliberately down here,
                        // away from the daily start/stop switch.
                        Button(uninstallArmed ? "Click again to uninstall" : "Uninstall daemon…") {
                            if uninstallArmed {
                                uninstallDisarm?.cancel()
                                uninstallArmed = false
                                model.setDaemonInstalled(false)
                            } else {
                                uninstallArmed = true
                                uninstallDisarm?.cancel()
                                uninstallDisarm = Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(3))
                                    if !Task.isCancelled { uninstallArmed = false }
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundStyle(uninstallArmed ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                        .focusable(false)
                        .help("Remove the launch agent (task-clock uninstall) — click twice")
                    }
                }
            }
            HStack {
                // Never disabled on !daemonUp: "down" also covers "starting
                // right now", and a reload against a truly down daemon just
                // reports in the same view (ambiguous-status rule).
                Button("Reload task definitions") { model.reload() }
                    .focusable(false)
                    .help("Tell the daemon to re-read its tasks.d config files (task-clock reload)")
                Spacer()
                // appVersion already carries the v prefix (git describe) —
                // adding another produced "vv0.1.0". Selectable so a bug
                // report can paste the exact build.
                Text(appVersion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .focusable(false)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 10, trailing: 12))
    }
}

/// Shared indicator glyphs (task rows and history rows): the quiet normal
/// state is a small pilot-lamp dot, not a full-size filled symbol — solid
/// fills read much heavier than the outline glyphs at the same point size.
struct IndicatorIcon: View {
    let indicator: RowIndicator

    var body: some View {
        Group {
            switch indicator {
            case .disabled:
                Image(systemName: Symbols.indicatorDisabled).foregroundStyle(.secondary)
            case .paused:
                Image(systemName: Symbols.indicatorPaused).foregroundStyle(.secondary)
            case .overrun:
                Image(systemName: Symbols.indicatorOverrun).foregroundStyle(.orange)
            case .running:
                Image(systemName: Symbols.indicatorRunning).foregroundStyle(.green)
            case .failed:
                Image(systemName: Symbols.indicatorFailed).foregroundStyle(.red)
            case .missedLast:
                Image(systemName: Symbols.indicatorMissed).foregroundStyle(.orange)
            case .healthy:
                Circle().fill(.green).frame(width: 10, height: 10)
            }
        }
        .font(.title3)
        .frame(width: 22, height: 22)
    }
}

struct TaskRow: View {
    let task: TaskView
    @ObservedObject var model: AppModel
    let now: Date

    /// Run-now interlock: the first click arms (orange confirm state), the
    /// second click within the window fires; the arm decays on its own.
    /// A single stray click can no longer launch a task (user feedback).
    @State private var runArmed = false
    @State private var disarmTask: Task<Void, Never>?

    var body: some View {
        let text = taskRowText(task, now: now)
        HStack(alignment: .center, spacing: 8) {
            IndicatorIcon(indicator: rowIndicator(for: task))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.name).font(.system(.body, weight: .medium))
                    Text(text.trigger)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: Symbols.historyChevron)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text("\(text.state) · next: \(text.nextRun) · last: \(text.lastRun)")
                    .font(.caption)
                    .foregroundStyle(stateColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            // Claim the leftover width and truncate inside it — combined
            // with the controls' layoutPriority this is what keeps a long
            // state line from squeezing the buttons out of the row.
            .frame(maxWidth: .infinity, alignment: .leading)
            // The row body opens the run history (Phase 2); the chevron is
            // the affordance.
            .contentShape(Rectangle())
            .onTapGesture { model.openHistory(task: task.name) }
            .help("Show run history")
            controls
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .frame(height: PopoverLayout.rowHeight)
    }

    private var state: TaskDisplayState { displayState(for: task) }

    private var stateColor: Color {
        state == .overrun ? .orange : .secondary
    }

    @ViewBuilder
    private var controls: some View {
        // Controls stay enabled in ambiguous states — running the action and
        // reporting the daemon's answer beats guessing what is possible.
        if task.enabled {
            Button {
                if runArmed {
                    disarmTask?.cancel()
                    runArmed = false
                    model.trigger(task: task.name)
                } else {
                    runArmed = true
                    disarmTask?.cancel()
                    disarmTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        if !Task.isCancelled { runArmed = false }
                    }
                }
            } label: {
                Image(systemName: runArmed ? Symbols.runNowArmed : Symbols.runNow)
                    .foregroundStyle(runArmed ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help(runArmed
                ? "Click again to run now"
                : "Run now — click twice (interlock; works even while off)")
        }
        if let log = task.lastRun?.logPath, !log.isEmpty {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: log)])
            } label: {
                Image(systemName: Symbols.revealLog)
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help("Reveal the last run's log in Finder")
        }
        if task.enabled {
            // The per-task on/off switch = pause/resume, which the daemon
            // persists across restarts. The config's `enabled = false` is a
            // different layer: declared in tasks.d, and honestly not
            // controllable from here — no switch is shown for it rather
            // than one that would do nothing.
            Toggle("", isOn: Binding(
                get: { !task.paused },
                set: { on in
                    on ? model.resume(task: task.name) : model.pause(task: task.name)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .focusable(false)
            .help(task.paused
                ? "Off — scheduling paused (persists until turned on)"
                : "On — scheduled; turn off to pause")
        }
    }
}
