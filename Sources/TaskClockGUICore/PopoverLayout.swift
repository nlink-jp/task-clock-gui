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
    public static let maxHeight: CGFloat = 420

    public static func contentHeight(rows: Int) -> CGFloat {
        let wanted = CGFloat(max(rows, 1)) * rowHeight
        return min(max(wanted, minHeight), maxHeight)
    }
}
