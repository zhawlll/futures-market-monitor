import SwiftUI

struct MonitorTableHeader: View {
    let metrics: [Metric]
    let source: DataSource?
    var body: some View {
        HStack(spacing: 0) {
            ForEach(metrics) { metric in Text(metric.title(for: source)).frame(width: metric.width, alignment: .trailing) }
            Spacer(minLength: 16)
            Text("数据更新时间").frame(width: MonitorLayout.updateTimeColumnWidth, alignment: .leading)
        }.font(.system(size: 12)).foregroundStyle(.secondary).frame(height: 16).padding(.trailing, 8).padding(.vertical, 12)
    }
}
