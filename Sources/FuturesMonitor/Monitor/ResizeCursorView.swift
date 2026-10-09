import AppKit
import SwiftUI

struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> ColumnResizeCursorView { ColumnResizeCursorView() }
    func updateNSView(_ view: ColumnResizeCursorView, context: Context) {}
}
