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
    /// `.list` matters: without it a foreground banner times out and leaves
    /// no trace in Notification Center — step away mid-run and the failure
    /// evidence is gone (verification finding A1; sensor-lens-gui had the
    /// same lesson recorded).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// Whether notifications are hard-denied — the popover states it, since
    /// stderr is a black hole for Finder/login launches and banners are a
    /// shipped behavior that can otherwise be permanently, silently dead.
    func checkDenied(_ completion: @escaping @MainActor (Bool) -> Void) {
        guard let center else {
            return completion(false)
        }
        center.getNotificationSettings { settings in
            let denied = settings.authorizationStatus == .denied
            DispatchQueue.main.async {
                completion(denied)
            }
        }
    }
}
