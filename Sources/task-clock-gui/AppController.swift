import AppKit
import Combine
import SwiftUI
import TaskClockGUICore

/// The status panel's window: takes key status without the app being
/// active (Esc handling, crisp control focus), never becomes main.
final class StatusPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the menu-bar presence and the resizable status panel.
///
/// Replaces `MenuBarExtra` with `NSStatusItem` + a resizable `NSPanel`
/// hosting the SwiftUI `PopoverView` — a MenuBarExtra window cannot be
/// user-resized, and the earlier grip workaround fought the framework
/// (jittery self-resize under the drag). The panel gives OS-native edge
/// resizing with correct anchoring and free size persistence. Ported from
/// instant-translate's AppController, org's proven shape for exactly this.
@MainActor
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    let model = AppModel()

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?
    private var lastShownAt = Date.distantPast
    private var clickMonitors: [Any] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel)
        }
        statusItem = item

        // TCC prompt timing: authorization must be requested at launch —
        // when a banner is finally needed, nobody is at the keyboard to
        // answer the one-time prompt.
        Notifier.shared.setupAtLaunch()
        model.start()

        // The status button mirrors model.menuBar (symbol + optional
        // overrun text); re-render on every model change.
        cancellable = model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.renderStatusButton() }
        renderStatusButton()

        // Pre-warm the panel so the first open pays no construction cost.
        _ = ensurePanel()
    }

    /// Click-away behaviour: dismiss when the app loses focus, via an
    /// explicit orderOut so `isVisible` stays accurate for togglePanel
    /// (never hidesOnDeactivate — it hides without clearing isVisible).
    /// The grace period keeps a launch/login focus bounce from hiding the
    /// panel right after it opens.
    func applicationDidResignActive(_ notification: Notification) {
        if Date().timeIntervalSince(lastShownAt) < 0.5 { return }
        hidePanel()
    }

    private func renderStatusButton() {
        guard let button = statusItem?.button else { return }
        let summary = model.menuBar
        button.image = NSImage(
            systemSymbolName: summary.symbolName,
            accessibilityDescription: "task-clock")
        button.image?.isTemplate = true
        button.title = summary.text.map { " " + $0 } ?? ""
    }

    // MARK: - Panel lifecycle

    @objc private func togglePanel() {
        let p = ensurePanel()
        if p.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        let p = ensurePanel()
        position(p)
        NSApp.activate()
        p.makeKeyAndOrderFront(nil)
        p.orderFrontRegardless() // front even if activation was denied
        lastShownAt = Date()
        installClickMonitors()
        model.popoverOpened()
    }

    private func hidePanel() {
        removeClickMonitors()
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        model.popoverClosed()
    }

    /// Click-away close. `applicationDidResignActive` alone is not enough:
    /// the panel is `.nonactivatingPanel`, so the app may never have been
    /// active in the first place — clicking the desktop or another app
    /// then produces no resign event at all. The org's proven answer
    /// (status-lens) is event monitors installed only while the panel is
    /// shown: a global monitor for clicks delivered to other apps, a local
    /// one for clicks in our own windows outside the panel.
    private func installClickMonitors() {
        removeClickMonitors()
        let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        let global = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hidePanel()
            }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            // NSEvent is not Sendable: extract what we need before hopping
            // into the isolated closure, and return the event outside it.
            let window = event.window
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, panel.isVisible else { return }
                if window === panel { return } // clicks inside stay inside
                // The status item button toggles the panel itself; closing
                // here too would make its click close-then-reopen.
                if window === self.statusItem?.button?.window { return }
                self.hidePanel()
            }
            return event
        }
        clickMonitors = [global, local].compactMap { $0 }
    }

    private func removeClickMonitors() {
        for monitor in clickMonitors {
            NSEvent.removeMonitor(monitor)
        }
        clickMonitors = []
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        // `.nonactivatingPanel` is essential: an ordinary panel only
        // renders while the app is active, and macOS 14+ focus-stealing
        // prevention can deny activation for ~30 s after launch — the
        // panel would be isVisible=true yet not on screen.
        let p = StatusPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.isFloatingPanel = true
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.animationBehavior = .utilityWindow
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.minSize = NSSize(width: 340, height: 300)
        p.setFrameAutosaveName("TaskClockPanel") // remembers the user's size

        let host = NSHostingView(rootView: PopoverView(model: model))
        host.autoresizingMask = [.width, .height]
        p.contentView = host
        panel = p
        return p
    }

    /// Anchor the panel under the status-bar button, clamped to the
    /// current screen so an autosaved size from a bigger display cannot
    /// push it off a smaller one.
    private func position(_ panel: NSPanel) {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let vis = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var size = panel.frame.size
        size.width = min(size.width, vis.width - 16)
        size.height = min(size.height, vis.height - 16)

        let inScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var origin = NSPoint(x: inScreen.midX - size.width / 2,
                             y: inScreen.minY - size.height - 6)
        origin.x = min(max(origin.x, vis.minX + 8), vis.maxX - size.width - 8)
        origin.y = min(max(origin.y, vis.minY + 8), vis.maxY - size.height - 8)

        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }
}
