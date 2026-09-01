import SwiftUI

/// The SwiftUI app shell. Deliberately NOT marked @main: entry lives in
/// Entry.swift's `enum Main`, which runs the single-instance guard first
/// and then calls `TaskClockApp.main()`. The menu-bar shell itself is
/// AppKit (AppController: NSStatusItem + resizable NSPanel) — MenuBarExtra
/// cannot host a user-resizable window; the Settings scene is the required
/// placeholder and opens no window.
struct TaskClockApp: App {
    @NSApplicationDelegateAdaptor(AppController.self) private var controller

    var body: some Scene {
        Settings { EmptyView() }
    }
}
