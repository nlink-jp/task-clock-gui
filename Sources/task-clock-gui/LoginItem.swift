import Foundation
import ServiceManagement

/// SMAppService launch-at-login wrapper. Registration requires a real app
/// bundle; the bare dev binary reports unavailable instead of failing.
///
/// `isEnabled` folds every non-enabled status (`.notFound` for a
/// never-registered app, `.notRegistered`, `.requiresApproval`) into
/// "not enabled yet" — an ambiguous status must never disable the toggle,
/// because the first registration is exactly the operation the user needs
/// (org lesson: sensor-lens-gui shipped a switch nobody could turn on).
@MainActor
enum LoginItem {
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
