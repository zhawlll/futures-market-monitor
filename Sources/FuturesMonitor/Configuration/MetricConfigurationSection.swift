import SwiftUI

struct MetricConfigurationSection: View {
    let source: DataSource?
    @Binding var metrics: [Metric]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("监控指标").font(.headline)
                Spacer()
                Button("全选") {
                    let selected = Set(metrics)
                    metrics.append(contentsOf: Metric.allCases.filter { !selected.contains($0) })
                }
                .disabled(metrics.count == Metric.allCases.count)
                .accessibilityIdentifier("selectAllMetrics")
                Button("取消全选") { metrics.removeAll() }
                    .disabled(metrics.isEmpty)
                    .accessibilityIdentifier("deselectAllMetrics")
            }
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 12) {
                ForEach(Metric.allCases) { metric in
                    Toggle(metric.title(for: source), isOn: Binding(
                        get: { metrics.contains(metric) },
                        set: { selected in
                            if selected { metrics.append(metric) }
                            else { metrics.removeAll { $0 == metric } }
                        }
                    )).toggleStyle(.checkbox)
                }
            }
            Text("指标将按勾选顺序显示为小窗中的列").font(.caption).foregroundStyle(.secondary)
            if metrics.contains(where: { $0.referencePart != nil }) {
                Text("1手价格为合约总价值，一手保证金按公司公示比例估算；保证金与手续费使用东方财富期货公司公示标准，点击小窗对应指标查看详情。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if source == .eastmoney {
                Text("涨跌幅按昨收计算，涨跌额按昨结计算").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
