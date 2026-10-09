import Foundation

enum MonitorLayout {
    static let instrumentWidth: CGFloat = 180
    static let fixedColumnWidth = instrumentWidth + 8
    static let updateTimeColumnWidth: CGFloat = 180
    static let minimumInstrumentColumnWidth: CGFloat = 176
    static let maximumInstrumentColumnWidth: CGFloat = 600
    static func clampInstrumentColumnWidth(_ width: CGFloat) -> CGFloat {
        guard width.isFinite else { return fixedColumnWidth }
        return min(maximumInstrumentColumnWidth, max(minimumInstrumentColumnWidth, width))
    }
    static func effectiveInstrumentColumnWidth(_ width: CGFloat, availableWidth: CGFloat) -> CGFloat {
        min(clampInstrumentColumnWidth(width), max(minimumInstrumentColumnWidth, availableWidth - 90))
    }
    static let rowContentHeight: CGFloat = 24
    static let headerHeight: CGFloat = 41
    static let minimumPadding: CGFloat = 3
    static let maximumPadding: CGFloat = 13
    static func metricsWidth(_ metrics: [Metric]) -> CGFloat {
        metrics.reduce(updateTimeColumnWidth + 16 + 8) { $0 + $1.width }
    }
    static func tableHeight(rowCount: Int, padding: CGFloat) -> CGFloat {
        headerHeight + CGFloat(max(0, rowCount)) * (rowContentHeight + padding * 2 + 1)
    }
    static func rowPadding(availableHeight: CGFloat, rowCount: Int) -> CGFloat {
        guard rowCount > 0 else { return maximumPadding }
        let padding = ((availableHeight - headerHeight) / CGFloat(rowCount) - rowContentHeight - 1) / 2
        return min(maximumPadding, max(minimumPadding, padding))
    }
}
