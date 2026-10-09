import SwiftUI

struct QuoteRowView: View {
    let row: MonitorRow
    let metrics: [Metric]
    let verticalPadding: CGFloat
    let references: BrokerSnapshot
    private var tooltip: String {
        var lines = ["主力连续行情", "数据源：\(row.quote?.source ?? row.instrument.quoteSource)"]
        lines.append(row.instrument.dataSource == .eastmoney ? "涨跌幅基准：上一交易日收盘价" : "涨跌幅基准：上一交易日结算价")
        if let quote = row.quote {
            if let close = quote.previousClose { lines.append("昨收价：\(close)") }
            lines.append("连续代码：\(quote.symbol)")
            lines.append("行情时间：\(quote.date) \(quote.tickTime)（北京时间）")
            lines.append("最近成功查询：\(quote.fetchedAt.formatted(date: .numeric, time: .standard))")
        }
        if let error = row.error { lines.append("查询失败：\(error)") }
        return lines.joined(separator: "\n")
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(metrics) { metric in
                if metric.referencePart != nil {
                    ReferenceMetricView(metric: metric, row: row, references: references)
                } else {
                Text(row.quote?.formatted(metric) ?? "-")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(valueColor(metric))
                    .frame(width: metric.width, alignment: .trailing)
                }
            }
            Spacer(minLength: 16)
            HStack(spacing: 5) {
                if row.status.isFailure { Image(systemName: "exclamationmark.triangle").font(.system(size: 11)) }
                Text(row.quote?.displayTime ?? "-").font(.system(size: 12).monospacedDigit())
            }.foregroundStyle(row.status.isFailure ? Color.red : Color.primary)
                .frame(width: MonitorLayout.updateTimeColumnWidth, alignment: .leading).help(tooltip)
        }.frame(height: MonitorLayout.rowContentHeight).padding(.trailing, 8).padding(.vertical, verticalPadding)
            .accessibilityElement(children: .contain)
    }
    private func valueColor(_ metric: Metric) -> Color {
        guard metric == .percent || metric == .change, let value = row.quote?.values[metric], value != 0 else { return .primary }
        return value > 0 ? .red : .green
    }
}
