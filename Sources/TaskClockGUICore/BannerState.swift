import Foundation

/// The popover's message banner, kept as two independent channels: what
/// the last status poll found, and what the user's last action reported.
///
/// Keeping them apart is the whole point. They used to share one field,
/// and every action erased its own message: an action sets the message and
/// then re-polls, and a successful poll cleared the field ~100 ms later.
/// A `trigger` the daemon refused — already running, unknown task, a CLI
/// that could not start — was therefore completely silent, which is
/// indistinguishable from never having clicked. So: a poll may never clear
/// the action's word. Only the next action, or closing the popover, does.
public struct BannerState: Equatable, Sendable {
    /// Problem found by the status poll. An unreachable daemon is *not*
    /// one of these — it is a distinct displayed state with its own
    /// explanation in the panel, never an error banner.
    public private(set) var pollError: String?

    /// What the user's last action reported: a failure, or a state that
    /// came out different from what was asked (launch-at-login awaiting
    /// approval, a daemon that did not stop). nil means the last action
    /// had nothing worth saying.
    public private(set) var actionNotice: String?

    public init(pollError: String? = nil, actionNotice: String? = nil) {
        self.pollError = pollError
        self.actionNotice = actionNotice
    }

    /// One status poll finished. `error` is nil when it succeeded, and
    /// also when it found the daemon down.
    public mutating func pollFinished(error: String?) {
        pollError = error
    }

    /// One user action finished. Its word replaces the previous one, so a
    /// successful retry clears the failure it was retrying.
    public mutating func actionFinished(notice: String?) {
        actionNotice = notice
    }

    /// Closing the popover ends the action's context — reopening must not
    /// land on the answer to a click from an hour ago.
    public mutating func popoverClosed() {
        actionNotice = nil
    }

    /// What the banner shows. The action's word comes first: it answers
    /// the click the user just made, while a poll error stands until the
    /// poll itself recovers.
    public var message: String? { actionNotice ?? pollError }
}
