import AppKit

final class HorizontalScrollObservationView: NSView {
    var offsetChanged: ((CGFloat) -> Void)?
    private var observer: NSObjectProtocol?
    private weak var observedClip: NSClipView?
    private var lastOffset: CGFloat?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attach()
    }

    private func attach() {
        guard let scroll = enclosingScrollView, scroll.hasHorizontalScroller else { return }
        let clip = scroll.contentView
        guard observedClip !== clip else { return }
        stopObserving()
        observedClip = clip
        clip.postsBoundsChangedNotifications = true
        observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
            object: clip, queue: .main) { [weak self] _ in self?.reportOffset() }
        reportOffset()
    }

    private func reportOffset() {
        guard let clip = observedClip else { return }
        let offset = -clip.bounds.origin.x
        guard offset != lastOffset else { return }
        lastOffset = offset
        // Deliver after the current layout pass to avoid state changes during updates.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.observedClip === clip, self.lastOffset == offset else { return }
            self.offsetChanged?(offset)
        }
    }

    func stopObserving() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        observedClip = nil
        lastOffset = nil
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
