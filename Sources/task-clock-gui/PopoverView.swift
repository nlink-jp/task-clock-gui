import SwiftUI
import TaskClockGUICore

// Design system (user feedback: piecemeal additions had made the panel
// visually noisy). Three text levels only: headline (title) / body (task
// names) / caption in secondary gray (all meta). Color marks STATE only,
// and state has ONE idiom — a small dot in the daemon lamp's color
// grammar (green/orange/red/gray); the caption text carries the reason.
// Switches align on the right edge, header and rows alike. Text buttons
// are uniformly small. Rare setup actions live in the gear menu, not in
// the always-visible footer.
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
            // Freshness lives in the tooltip, not as always-on text: the
            // panel self-polls every 5 s, so a visible timestamp was
            // process detail masquerading as information.
            Circle()
                .fill(lampColor(lamp))
                .frame(width: 8, height: 8)
                .help(lampHelp(lamp))
            Text(lampCaption(lamp))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            // Right edge = the switch column, shared with the task rows.
            // Always rendered and always live — the switch IS the run
            // intent, and on a fresh machine turning it on simply
            // includes the setup (install registers and starts). No
            // separate Install button, no popping elements.
            Toggle("", isOn: Binding(
                get: { model.daemonEnabled && model.daemonInstalled },
                set: { model.setDaemonRunning($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .focusable(false)
            .help(model.daemonInstalled
                ? "Power: start / stop the daemon. Stopping never kills running tasks; they are picked up again on start."
                : "Power: installs the launch agent and starts the daemon")
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
    }

    private func lampHelp(_ state: DaemonLampState) -> String {
        guard let updated = model.lastUpdated else { return daemonLampText(state) }
        return "\(daemonLampText(state)) — updated \(updated.formatted(date: .omitted, time: .standard))"
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
            Text("task-clock runs as a background daemon. Flip the switch above to install its launch agent and start it — it runs now and at every login.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        } else if model.daemonEnabled {
            // Stalled. Restart lives HERE, not in the header: a button
            // popping into the title row made the layout twitch.
            VStack(alignment: .leading, spacing: 8) {
                Text("The daemon should be running but is not answering — it may still be starting, or its config may be invalid (`task-clock validate` diagnoses config problems).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Restart") { model.setDaemonInstalled(true) }
                    .controlSize(.small)
                    .focusable(false)
                    .help("Re-register the launch agent (task-clock install)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        } else {
            Text("The daemon is stopped. Tasks are not being scheduled; flip the switch above to start it. Any still-running task keeps running and is picked up again on start.")
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
            HStack(spacing: 24) {
                // Never disabled on !daemonUp: "down" also covers "starting
                // right now", and a reload against a truly down daemon just
                // reports in the same view (ambiguous-status rule).
                Button {
                    model.reload()
                } label: {
                    Label("Reload tasks", systemImage: Symbols.reload)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .focusable(false)
                .help("Tell the daemon to re-read its tasks.d config files (task-clock reload)")
                daemonSetupButton
                Spacer()
            }
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
                // appVersion already carries the v prefix (git describe) —
                // adding another produced "vv0.1.0". Selectable so a bug
                // report can paste the exact build.
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                // Quitting the app never touches the daemon, so the power
                // button needs no interlock or confirmation.
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: Symbols.quitApp)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("Quit TaskClock — the daemon keeps running")
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 10, trailing: 12))
    }

    /// Setup control beside the power switch: installs plainly;
    /// uninstalling — the destructive direction — takes the
    /// run-now-style two-click interlock (armed = orange, decays on its
    /// own).
    @ViewBuilder
    private var daemonSetupButton: some View {
        if model.daemonInstalled {
            Button {
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
            } label: {
                // Armed = color only; the label stays put (user feedback:
                // changing text was the noisier signal).
                Label("Uninstall", systemImage: Symbols.uninstallDaemon)
                    .font(.caption)
                    .foregroundStyle(uninstallArmed ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help(uninstallArmed
                ? "Click again to uninstall the daemon"
                : "Uninstall the daemon's launch agent — click twice; a running task is not killed")
        } else {
            Button {
                model.setDaemonInstalled(true)
            } label: {
                Label("Install", systemImage: Symbols.installDaemon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help("Install and start the daemon — same as flipping the switch on")
        }
    }
}

/// Shared state indicator (task rows and history rows): ONE idiom
/// app-wide — a small dot in the daemon lamp's color grammar. The caption
/// text next to it carries the reason; a per-state symbol zoo carried the
/// same information twice and read as noise (user feedback).
struct IndicatorIcon: View {
    let indicator: RowIndicator

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .frame(width: 16, height: 16)
    }

    private var dotColor: Color {
        switch indicator {
        case .disabled, .paused: return Color(nsColor: .tertiaryLabelColor)
        case .overrun, .missedLast: return .orange
        case .failed: return .red
        case .running, .healthy: return .green
        }
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
                    // The trigger spec (cron/watermark) is static config —
                    // it moved to the history header; "next:" below is
                    // what the schedule means for the user.
                    Image(systemName: Symbols.historyChevron)
                        .font(.caption)
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
                // Fixed frame: the armed glyph is wider than the idle one,
                // and a button that changes width nudges the whole row.
                Image(systemName: runArmed ? Symbols.runNowArmed : Symbols.runNow)
                    .foregroundStyle(runArmed ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
                    .frame(width: 18)
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help(runArmed
                ? "Click again to run now"
                : "Run now — click twice (interlock; works even while off)")
        }
        // No reveal-log button here: every run's log is one click away in
        // the history view the row opens — the duplicate icon was noise.
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
