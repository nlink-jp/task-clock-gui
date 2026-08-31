import SwiftUI
import TaskClockGUICore

/// The SwiftUI app. Deliberately NOT marked @main: a `@main struct: App`
/// runs its @StateObject initializers before any guard code could, so entry
/// lives in Entry.swift's `enum Main`, which runs the single-instance guard
/// first and then calls `TaskClockApp.main()`.
struct TaskClockApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
                .onAppear { model.popoverOpened() }
                .onDisappear { model.popoverClosed() }
        } label: {
            let summary = model.menuBar
            Group {
                if let text = summary.text {
                    Label(text, systemImage: summary.symbolName)
                } else {
                    Image(systemName: summary.symbolName)
                }
            }
            // The label is rendered when the status item is created at
            // launch — the one reliable lifecycle hook a MenuBarExtra app
            // has. AppModel.start() is idempotent-adjacent via its timer
            // replacement, but guard anyway.
            .onAppear { AppStart.once(model: model) }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
enum AppStart {
    private static var started = false

    static func once(model: AppModel) {
        guard !started else { return }
        started = true
        // TCC prompt timing: authorization must be requested now, at
        // launch — when a banner is finally needed there is nobody at the
        // keyboard to answer the one-time prompt.
        Notifier.shared.setupAtLaunch()
        model.start()
    }
}
