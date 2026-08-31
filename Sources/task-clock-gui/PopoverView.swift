import SwiftUI
import TaskClockGUICore

struct PopoverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            daemonRow
            Divider()
            content
            if let error = model.lastError {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
                    .padding(8)
            }
            Divider()
            footer
        }
        .frame(width: 380)
        // The popover sizes itself to the content's ideal height; make the
        // VStack claim what it needs instead of being squeezed.
        .fixedSize(horizontal: false, vertical: true)
    }

    // No manual refresh button: the popover auto-polls every 5 s while
    // open and every action re-polls, so a display-refresh control would
    // only be mistaken for the daemon-side "Reload tasks" below. The
    // timestamp shows the freshness instead.
    private var header: some View {
        HStack {
            Text("task-clock").font(.headline)
            Spacer()
            if let updated = model.lastUpdated {
                Text("as of \(updated, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
    }

    /// Pilot lamp (actual state) + power switch (launch-agent intent):
    /// the same controls in every state — no asymmetric big-button/checkbox
    /// split. An ON switch with an orange lamp is precisely
    /// "registered but not answering", and Restart is its repair path.
    private var daemonRow: some View {
        let lamp = daemonLamp(installed: model.daemonInstalled, up: model.daemonUp)
        return HStack(spacing: 8) {
            Circle()
                .fill(lampColor(lamp))
                .frame(width: 10, height: 10)
            Text(daemonLampText(lamp))
                .font(.callout)
            if lamp == .stalled {
                Button("Restart") { model.setDaemonInstalled(true) }
                    .controlSize(.small)
                    .help("Re-register the launch agent (task-clock install)")
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { model.daemonInstalled },
                set: { model.setDaemonInstalled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .help("Power: register / remove the task-clock launch agent (starts and stops the daemon)")
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    private func lampColor(_ state: DaemonLampState) -> Color {
        switch state {
        case .running: return .green
        case .stalled: return .orange
        case .stopped: return Color(nsColor: .tertiaryLabelColor)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.daemonUp {
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
            // ScrollView has ideal height 0 in a menu-bar popover — give it
            // the concrete height PopoverLayout computes, or it collapses.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.tasks, id: \.name) { task in
                        TaskRow(task: task, model: model)
                        if task.name != model.tasks.last?.name {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
            .frame(height: PopoverLayout.contentHeight(rows: model.tasks.count))
        }
    }

    private var daemonDown: some View {
        Text(model.daemonInstalled
            ? "The launch agent is registered but not answering — it may still be starting, or its config may be invalid (try Restart above; `task-clock validate` diagnoses config problems)."
            : "task-clock runs as a background daemon. Flip the switch above to register its launch agent — it starts now and at every login.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if model.loginItemAvailable {
                HStack {
                    Toggle("Launch at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help("Open this menu-bar app when you log in")
                    Spacer()
                }
            }
            HStack {
                Button("Reload task definitions") { model.reload() }
                    .disabled(!model.daemonUp)
                    .help("Tell the daemon to re-read its tasks.d config files (task-clock reload)")
                Spacer()
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 10, trailing: 12))
    }
}

struct TaskRow: View {
    let task: TaskView
    @ObservedObject var model: AppModel

    var body: some View {
        let text = taskRowText(task, now: Date())
        HStack(alignment: .center, spacing: 8) {
            stateIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.name).font(.system(.body, weight: .medium))
                    Text(text.trigger)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(text.state) · next: \(text.nextRun) · last: \(text.lastRun)")
                    .font(.caption)
                    .foregroundStyle(stateColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            controls
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .frame(height: PopoverLayout.rowHeight)
    }

    private var state: TaskDisplayState { displayState(for: task) }

    private var stateIcon: some View {
        Group {
            switch state {
            case .overrun:
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            case .running:
                Image(systemName: "play.circle.fill").foregroundStyle(.blue)
            case .paused:
                Image(systemName: "pause.circle").foregroundStyle(.secondary)
            case .disabled:
                Image(systemName: "minus.circle").foregroundStyle(.secondary)
            case .idle:
                Image(systemName: "circle").foregroundStyle(.secondary)
            }
        }
        .font(.title3)
    }

    private var stateColor: Color {
        state == .overrun ? .orange : .secondary
    }

    @ViewBuilder
    private var controls: some View {
        // Controls stay enabled in ambiguous states — running the action and
        // reporting the daemon's answer beats guessing what is possible.
        if task.enabled {
            Button {
                model.trigger(task: task.name)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .help("Run now (works even while off)")
        }
        if let log = task.lastRun?.logPath, !log.isEmpty {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: log)])
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .buttonStyle(.borderless)
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
            .help(task.paused
                ? "Off — scheduling paused (persists until turned on)"
                : "On — scheduled; turn off to pause")
        }
    }
}
