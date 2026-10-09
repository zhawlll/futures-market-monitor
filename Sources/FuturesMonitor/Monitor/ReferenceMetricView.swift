import SwiftUI

struct ReferenceMetricView: View {
    let metric: Metric
    let row: MonitorRow
    let references: BrokerSnapshot
    @State private var showDetails = false
    var body: some View {
        Button { showDetails.toggle() } label: {
            HStack(spacing: 4) {
                Text(references.formatted(metric, row: row)).lineLimit(1).truncationMode(.tail)
                if references.error(for: metric) != nil { Image(systemName: "exclamationmark.triangle").font(.system(size: 10)) }
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }.font(.system(size: 13).monospacedDigit())
                .foregroundStyle(references.error(for: metric) != nil ? Color.red : Color.primary)
                .frame(width: metric.width, height: MonitorLayout.rowContentHeight, alignment: .trailing)
        }.buttonStyle(MonitorContentButtonStyle()).help(references.details(metric, row: row))
            .accessibilityLabel("查看\(row.instrument.name)\(metric.title)详情")
            .accessibilityValue(references.formatted(metric, row: row))
            .popover(isPresented: $showDetails) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(metric.title).font(.headline)
                    Text(references.details(metric, row: row)).font(.system(size: 12)).textSelection(.enabled)
                    ForEach(metric.referenceParts, id: \.self) { part in
                        Link("查看\(part.name)官方资料", destination: part == .contracts ? URL(string: "https://qhmob.eastmoney.com/traderule.html")! : part.url)
                    }
                }.padding(18).frame(width: 360, alignment: .leading)
            }
    }
}
