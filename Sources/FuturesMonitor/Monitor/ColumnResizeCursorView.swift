import AppKit

final class ColumnResizeCursorView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
