import SwiftUI
import TaskClockGUICore

struct PopoverView: View {
    @ObservedObject var model: AppModel

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
        .frame(width: 380)
        // The popover sizes itself to the content's ideal height; make the
        // VStack claim what it needs instead of being squeezed.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack {
            Text("task-clock").font(.headline)
            Spacer()
            if let updated = model.lastUpdated {
                Text(updated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
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
        VStack(alignment: .leading, spacing: 8) {
            Label("Daemon is not running", systemImage: "clock.badge.questionmark")
                .font(.callout)
            Text("Start it with `task-clock serve`, or register the launch agent with `task-clock install`.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var footer: some View {
        HStack {
            Button("Reload tasks") { model.reload() }
                .disabled(!model.daemonUp)
                .help("Re-read tasks.d (task-clock reload)")
            Spacer()
            Text("v\(appVersion)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Quit") { NSApplication.shared.terminate(nil) }
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
            .help("Run now")

            Button {
                task.paused ? model.resume(task: task.name) : model.pause(task: task.name)
            } label: {
                Image(systemName: task.paused ? "play.circle" : "pause.circle")
            }
            .buttonStyle(.borderless)
            .help(task.paused ? "Resume scheduling" : "Pause scheduling")
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
    }
}
