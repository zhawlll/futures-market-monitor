import AppKit
import SwiftUI

@main
enum FuturesMonitorMain {
    @MainActor static func main() async {
        let args = CommandLine.arguments
        if args.contains("--self-test") { exit(await SelfTests.run() ? 0 : 1) }
        if args.contains("--live-check") { exit(await SelfTests.liveCheck() ? 0 : 1) }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate(demo: args.contains("--demo"), settings: args.contains("--demo-settings"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
