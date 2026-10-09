import AppKit
import SwiftUI

struct InstrumentColumnResizeHandle: View {
    let store: MonitorStore
    let effectiveWidth: CGFloat
    let availableWidth: CGFloat
    @State private var initialWidth: CGFloat?
    @State private var hovered = false

    var body: some View {
        Rectangle().fill(hovered || initialWidth != nil ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
            .background { ResizeCursorView() }
            .onHover { hovered = $0 }
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { drag in
                    if initialWidth == nil { initialWidth = effectiveWidth }
                    let requested = (initialWidth ?? effectiveWidth) + drag.translation.width
                    store.setInstrumentColumnWidth(MonitorLayout.effectiveInstrumentColumnWidth(requested, availableWidth: availableWidth), persist: false)
                }
                .onEnded { _ in
                    initialWidth = nil
                    store.setInstrumentColumnWidth(store.instrumentColumnWidth)
                })
            .help("拖动调整品种列宽；右键可恢复默认宽度")
            .contextMenu {
                Button("恢复默认列宽", action: resetWidth)
            }
            .accessibilityElement()
            .accessibilityLabel("品种列宽")
            .accessibilityValue("\(Int(effectiveWidth)) 点")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjustWidth(10)
                case .decrement: adjustWidth(-10)
                @unknown default: break
                }
            }
            .accessibilityAction(named: "恢复默认列宽", resetWidth)
    }

    private func resetWidth() { store.setInstrumentColumnWidth(MonitorLayout.fixedColumnWidth) }
    private func adjustWidth(_ amount: CGFloat) {
        store.setInstrumentColumnWidth(MonitorLayout.effectiveInstrumentColumnWidth(effectiveWidth + amount, availableWidth: availableWidth))
    }
}
