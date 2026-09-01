import SwiftUI
import TaskClockGUICore

struct PopoverView: View {
    @ObservedObject var model: AppModel

    // Panel size, user-adjustable via the resize grip and persisted.
    // MenuBarExtra windows have no native resize frame — the window tracks
    // its content's ideal size, so dragging the grip mutates these and the
    // window follows.
    @AppStorage("panelWidth") private var panelWidth = Double(PopoverLayout.defaultWidth)
    @AppStorage("listMaxHeight") private var listMaxHeight = Double(PopoverLayout.maxHeight)
    @State private var dragStart: (width: Double, height: Double)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
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
        .frame(width: panelWidth)
        // The popover sizes itself to the content's ideal height; make the
        // VStack claim what it needs instead of being squeezed.
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .bottomTrailing) { resizeGrip }
    }

    var listHeightCap: CGFloat { CGFloat(listMaxHeight) }

    /// Bottom-right resize grip: drag to resize width and list height,
    /// double-click to restore the defaults.
    private var resizeGrip: some View {
        Image(systemName: "arrow.up.backward.and.arrow.down.forward")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(90)) // point along the ↘ diagonal
            .padding(4)
            .contentShape(Rectangle())
            .help("Drag to resize — double-click to reset")
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let start = dragStart ?? (panelWidth, listMaxHeight)
                        dragStart = start
                        panelWidth = Double(PopoverLayout.clampWidth(
                            CGFloat(start.width) + value.translation.width))
                        listMaxHeight = Double(PopoverLayout.clampListHeight(
                            CGFloat(start.height) + value.translation.height))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) {
                panelWidth = Double(PopoverLayout.defaultWidth)
                listMaxHeight = Double(PopoverLayout.maxHeight)
            }
    }

    /// Title line carries the daemon pilot lamp + power switch
    /// (load-spinner's header pattern): the lamp shows the actual state,
    /// the switch holds the launch-agent intent, and an ON switch with an
    /// orange lamp is precisely "registered but not answering" — Restart
    /// is its repair path. No manual refresh button: the popover
    /// auto-polls every 5 s and every action re-polls; the timestamp shows
    /// the freshness instead.
    private var header: some View {
        let lamp = daemonLamp(installed: model.daemonInstalled, up: model.daemonUp)
        return HStack(spacing: 6) {
            Text("task-clock").font(.headline)
            Circle()
                .fill(lampColor(lamp))
                .frame(width: 7, height: 7)
                .help(daemonLampText(lamp))
            Text(lampCaption(lamp))
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("", isOn: Binding(
                get: { model.daemonInstalled },
                set: { model.setDaemonInstalled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .help("Power: register / remove the task-clock launch agent (starts and stops the daemon)")
            if lamp == .stalled {
                Button("Restart") { model.setDaemonInstalled(true) }
                    .controlSize(.small)
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
        }
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
        if let task = model.historyTask {
            HistoryView(model: model, taskName: task, heightCap: listHeightCap)
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
            //
            // ScrollView has ideal height 0 in a menu-bar popover — give it
            // the concrete height PopoverLayout computes, or it collapses.
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
                .frame(height: PopoverLayout.contentHeight(
                    rows: model.tasks.count, cap: listHeightCap))
            }
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
                // appVersion already carries the v prefix (git describe) —
                // adding another produced "vv0.1.0".
                Text(appVersion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Quit") { NSApplication.shared.terminate(nil) }
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
                Image(systemName: "minus.circle").foregroundStyle(.secondary)
            case .paused:
                Image(systemName: "pause.circle").foregroundStyle(.secondary)
            case .overrun:
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            case .running:
                Image(systemName: "play.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .missedLast:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
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
                    Image(systemName: "chevron.right")
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
                Image(systemName: runArmed ? "play.circle.fill" : "play.fill")
                    .foregroundStyle(runArmed ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
            }
            .buttonStyle(.borderless)
            .help(runArmed
                ? "Click again to run now"
                : "Run now — click twice (interlock; works even while off)")
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
