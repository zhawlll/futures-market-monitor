// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FuturesMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "FuturesMonitorCore",
            path: "Sources/FuturesMonitor",
            exclude: [
                "Application", "Testing",
                "Configuration/ConfigurationView.swift", "Configuration/DataSourceSection.swift",
                "Configuration/InstrumentConfigurationSection.swift", "Configuration/InstrumentPicker.swift",
                "Configuration/MetricConfigurationSection.swift", "Configuration/QueryIntervalSection.swift",
                "Monitor/MonitorView.swift", "Monitor/MonitorTableHeader.swift", "Monitor/QuoteRowView.swift",
                "Monitor/ReferenceMetricView.swift", "Monitor/StatusBadge.swift",
                "Monitor/MonitorTableView.swift", "Monitor/InstrumentCellView.swift",
                "Monitor/HorizontalScrollObserver.swift", "Monitor/HorizontalScrollObservationView.swift",
                "Monitor/InstrumentColumnResizeHandle.swift", "Monitor/ResizeCursorView.swift", "Monitor/ColumnResizeCursorView.swift"
            ]
        ),
        .testTarget(
            name: "FuturesMonitorCoreTests",
            dependencies: ["FuturesMonitorCore"],
            path: "Tests",
            exclude: ["Fixtures"]
        )
    ],
    // Keep the app's language mode while supporting the installed Swift 6.0 toolchain.
    // Tests use APIs also available on Swift 6.2 and later.
    swiftLanguageModes: [.v5]
)
