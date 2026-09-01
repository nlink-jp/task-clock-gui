import SwiftUI
import TaskClockGUICore

/// Per-task run history (Phase 2): the popover's second face, entered by
/// clicking a task row and left through the back button. Rows follow the
/// scheduled-vs-actual record: scheduled fire, start delay, duration,
/// result — the daemon's whole point, one line per fire.
struct HistoryView: View {
    @ObservedObject var model: AppModel
    let taskName: String
    let heightCap: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if let error = model.historyError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
                    .padding(8)
            } else if model.historyRuns.isEmpty {
                Text("No runs recorded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                // Explicit height, same as the task list: a ScrollView in a
                // menu-bar popover collapses without one.
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.historyRuns, id: \.id) { run in
                            HistoryRow(run: run)
                        }
                    }
                }
                .frame(height: PopoverLayout.historyContentHeight(
                    rows: model.historyRuns.count, cap: heightCap))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                model.closeHistory()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .buttonStyle(.borderless)
            .help("Back to the task list")
            Text(taskName).font(.system(.body, weight: .medium))
            Text("run history")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("last \(model.historyRuns.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }
}

struct HistoryRow: View {
    let run: Run

    var body: some View {
        let text = runRowText(run)
        HStack(spacing: 8) {
            IndicatorIcon(indicator: runRowIndicator(for: run))
                .scaleEffect(0.8)
            Text(text.clock)
                .font(.system(.caption, design: .monospaced))
            Text(text.startDelay)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 34, alignment: .leading)
            Text(text.duration)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .leading)
            Text(text.result)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            if !run.logPath.isEmpty {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: run.logPath)])
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("Reveal this run's log in Finder")
            }
        }
        .padding(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
        .frame(height: PopoverLayout.historyRowHeight)
    }
}
