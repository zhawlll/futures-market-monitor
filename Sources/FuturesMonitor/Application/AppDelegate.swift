import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store: MonitorStore
    private var monitor: NSPanel?
    private var settings: NSWindow?
    private var statusItem: NSStatusItem?
    private let demo: Bool
    private let showDemoSettings: Bool

    init(demo: Bool = false, settings: Bool = false) {
        self.demo = demo
        self.showDemoSettings = settings
        self.store = MonitorStore(demo: demo)
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        installStatusItem()
        if demo && showDemoSettings {
            store.configuration = MonitorConfiguration()
            store.rows = []
            showSettings()
        }
        else if demo { store.installDemoRows(); showMonitor() }
        else if store.configuration.valid { showMonitor(); store.startWorkers() }
        else { showSettings() }
        Task { await store.loadCatalog() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if store.configuration.valid { showMonitor() } else { showSettings() }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { store.stopWorkers() }
    @objc private func willSleep() { store.stopWorkers() }
    @objc private func didWake() { if !demo { store.startWorkers() } }

    private func installMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于期货行情监控", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let configure = appMenu.addItem(withTitle: "监控配置…", action: #selector(openSettings), keyEquivalent: ",")
        configure.target = self
        appMenu.addItem(withTitle: "隐藏期货行情监控", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出期货行情监控", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        bar.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        bar.addItem(editItem)
        NSApp.mainMenu = bar
    }
    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "chart.xyaxis.line", accessibilityDescription: "期货行情监控")
        let menu = NSMenu()
        for (title, selector) in [("显示行情小窗", #selector(openMonitor)), ("监控配置…", #selector(openSettings)), ("暂停 / 继续", #selector(pause))] {
            let item = menu.addItem(withTitle: title, action: selector, keyEquivalent: "")
            item.target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem?.menu = menu
    }
    @objc private func openMonitor() { if store.configuration.valid { showMonitor() } else { showSettings() } }
    @objc private func openSettings() { showSettings() }
    @objc private func pause() { if !demo { store.togglePause() } }

    private func showSettings() {
        if let settings, settings.isVisible { settings.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 590, height: 690),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "期货行情监控设置"
        window.identifier = NSUserInterfaceItemIdentifier("configurationWindow")
        window.minSize = NSSize(width: 560, height: 630)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ConfigurationView(store: store,
            cancel: { [weak window] in window?.close() },
            commit: { [weak self, weak window] draft in
                guard let self else { return }
                self.store.save(draft)
                self.showMonitor()
                window?.close()
            }))
        window.center()
        settings = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func showMonitor() {
        if monitor == nil {
            let width = min(1200, store.instrumentColumnWidth + 1 + MonitorLayout.metricsWidth(store.configuration.metrics))
            let height = min(550, 144 + CGFloat(max(1, store.rows.count)) * (MonitorLayout.rowContentHeight + 27))
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            panel.title = "期货行情监控"
            panel.titleVisibility = .hidden
            panel.identifier = NSUserInterfaceItemIdentifier("monitorWindow")
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = store.configuration.pinned
            panel.level = store.configuration.pinned ? .floating : .normal
            panel.collectionBehavior = [.fullScreenAuxiliary]
            panel.minSize = NSSize(width: 360, height: 172)
            panel.contentView = NSHostingView(rootView: MonitorView(store: store,
                configure: { [weak self] in self?.showSettings() },
                pin: { [weak self] in self?.togglePin() }))
            panel.center()
            if !demo { panel.setFrameAutosaveName("FuturesMonitor.Panel") }
            monitor = panel
        }
        synchronizePin()
        monitor?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func togglePin() {
        store.setPinned(!store.configuration.pinned)
        synchronizePin()
    }
    private func synchronizePin() {
        monitor?.level = store.configuration.pinned ? .floating : .normal
        monitor?.isFloatingPanel = store.configuration.pinned
    }
}
