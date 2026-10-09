import AppKit
import SwiftUI

struct HorizontalScrollObserver: NSViewRepresentable {
    let offsetChanged: (CGFloat) -> Void

    func makeNSView(context: Context) -> HorizontalScrollObservationView {
        let view = HorizontalScrollObservationView()
        view.offsetChanged = offsetChanged
        return view
    }

    func updateNSView(_ view: HorizontalScrollObservationView, context: Context) {
        view.offsetChanged = offsetChanged
    }

    static func dismantleNSView(_ view: HorizontalScrollObservationView, coordinator: ()) {
        view.stopObserving()
    }
}
