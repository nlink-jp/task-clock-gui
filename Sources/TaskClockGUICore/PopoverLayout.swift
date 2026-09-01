import Foundation

/// Menu-bar popovers size themselves to their content's *ideal* size, and a
/// ScrollView's ideal height is zero — so list areas need a concrete height
/// or they collapse to nothing (org lesson: sensor-lens-gui shipped with an
/// invisible device list). The estimate is deliberately rough; scrolling
/// absorbs the error. Floor keeps a short list visible, cap keeps a long
/// one on screen.
public enum PopoverLayout {
    public static let rowHeight: CGFloat = 52
    public static let minHeight: CGFloat = 64
    /// Default list-height cap; the user can drag the resize grip to move
    /// it within panel bounds.
    public static let maxHeight: CGFloat = 420

    /// User-resizable panel bounds (grip-driven; MenuBarExtra windows have
    /// no native resize frame, so the grip adjusts persisted state and the
    /// window follows its content size).
    public static let defaultWidth: CGFloat = 380
    public static let minWidth: CGFloat = 320
    public static let maxWidth: CGFloat = 680
    public static let minListHeight: CGFloat = 160
    public static let maxListHeight: CGFloat = 820

    /// Clamp a grip-dragged size into the allowed panel bounds.
    public static func clampWidth(_ w: CGFloat) -> CGFloat {
        min(max(w, minWidth), maxWidth)
    }

    public static func clampListHeight(_ h: CGFloat) -> CGFloat {
        min(max(h, minListHeight), maxListHeight)
    }

    public static func contentHeight(rows: Int, cap: CGFloat = maxHeight) -> CGFloat {
        let wanted = CGFloat(max(rows, 1)) * rowHeight
        return min(max(wanted, minHeight), max(cap, minHeight))
    }

    /// History rows are slimmer than task rows; same floor/cap discipline.
    public static let historyRowHeight: CGFloat = 28

    public static func historyContentHeight(rows: Int, cap: CGFloat = maxHeight) -> CGFloat {
        let wanted = CGFloat(max(rows, 1)) * historyRowHeight
        return min(max(wanted, minHeight), max(cap, minHeight))
    }
}
