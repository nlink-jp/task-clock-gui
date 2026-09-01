import Foundation

/// Row metrics for the panel's lists. The panel window is user-resizable
/// (AppKit NSPanel) and supplies the content size, so there is no
/// content-height math here any more — only the fixed row heights the row
/// views frame themselves with.
public enum PopoverLayout {
    public static let rowHeight: CGFloat = 52
    /// History rows are slimmer than task rows.
    public static let historyRowHeight: CGFloat = 28
}
