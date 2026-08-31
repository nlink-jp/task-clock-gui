import Foundation
import UserNotifications
import TaskClockGUICore

/// UNUserNotificationCenter wrapper.
///
/// Authorization is requested **at launch**: the system prompt appears only
/// while the status is .notDetermined, and the moment a banner is actually
/// needed (a task failing at 3 AM) is exactly when nobody is there to
/// answer it. A denial is surfaced on stderr with the recovery path — the
/// only one macOS offers is System Settings › Notifications.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private var center: UNUserNotificationCenter? {
        // The bare `swift run` binary has no bundle identifier and the
        // notification center throws on access — notifications are a
        // packaged-.app feature.
        Bundle.main.bundleIdentifier != nil ? .current() : nil
    }

    func setupAtLaunch() {
        guard let center else { return }
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                FileHandle.standardError.write(Data(
                    "task-clock-gui: notification authorization failed: \(error.localizedDescription)\n".utf8))
                return
            }
            if !granted {
                FileHandle.standardError.write(Data(
                    "task-clock-gui: notifications are denied — enable them in System Settings › Notifications › TaskClock\n".utf8))
            }
        }
    }

    func post(_ events: [NotifyEvent]) {
        guard let center else { return }
        for event in events {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default
            // trigger: nil is fine for a resident app — the banner belongs
            // to this process and this process stays alive.
            center.add(UNNotificationRequest(
                identifier: event.id, content: content, trigger: nil))
        }
    }

    /// Show banners even though the (menu-bar) app counts as foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
