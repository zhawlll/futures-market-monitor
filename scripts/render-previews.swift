// Render the actual SwiftUI views offscreen with synthetic demo data.
import AppKit
import SwiftUI

@main
struct PreviewRenderer {
    @MainActor static func render<V: View>(_ view: V, size: NSSize, to path: URL, scrollToEnd: Bool = false, scrollToBottom: Bool = false) throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: view)
        window.contentView = host
        host.setFrameSize(size)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        host.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        if scrollToEnd {
            guard let scroll = descendants(host).compactMap({ $0 as? NSScrollView })
                .first(where: { $0.hasHorizontalScroller && ($0.documentView?.frame.width ?? 0) > $0.contentSize.width }) else {
                throw NSError(domain: "Preview", code: 3, userInfo: [NSLocalizedDescriptionKey: "找不到横向滚动区域"])
            }
            let maximum = (scroll.documentView?.frame.width ?? 0) - scroll.contentSize.width
            scroll.contentView.scroll(to: NSPoint(x: maximum, y: scroll.contentView.bounds.origin.y))
            scroll.reflectScrolledClipView(scroll.contentView)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            host.layoutSubtreeIfNeeded()
            guard scroll.contentView.bounds.origin.x > 0 else { throw NSError(domain: "Preview", code: 4) }
            print("横向滚动至 \(scroll.contentView.bounds.origin.x) 点；固定列宽 \(MonitorLayout.fixedColumnWidth) 点")
        }
        if scrollToBottom {
            guard let scroll = descendants(host).compactMap({ $0 as? NSScrollView })
                .first(where: { $0.hasVerticalScroller && ($0.documentView?.frame.height ?? 0) > $0.contentSize.height }) else {
                throw NSError(domain: "Preview", code: 5, userInfo: [NSLocalizedDescriptionKey: "找不到纵向滚动区域"])
            }
            let maximum = (scroll.documentView?.frame.height ?? 0) - scroll.contentSize.height
            scroll.contentView.scroll(to: NSPoint(x: scroll.contentView.bounds.origin.x, y: maximum))
            scroll.reflectScrolledClipView(scroll.contentView)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            host.layoutSubtreeIfNeeded()
            print("纵向滚动至 \(scroll.contentView.bounds.origin.y) 点")
        }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "Preview", code: 1) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "Preview", code: 2) }
        try data.write(to: path)
        print(path.path.replacingOccurrences(of: NSHomeDirectory() + "/", with: "~/"))
    }
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("doc/images")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let store = MonitorStore(demo: true)
        store.installDemoRows()
        try render(MonitorView(store: store, configure: {}, pin: {}), size: NSSize(width: 800, height: 240), to: output.appendingPathComponent("monitor-demo.png"))
        try render(ConfigurationView(store: store, cancel: {}, commit: { _ in }), size: NSSize(width: 650, height: 1050), to: output.appendingPathComponent("configuration-demo.png"))
    }
}
