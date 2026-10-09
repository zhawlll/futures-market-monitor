import SwiftUI

struct InstrumentCellView: View {
    let row: MonitorRow
    let verticalPadding: CGFloat
    var columnWidth: CGFloat = MonitorLayout.fixedColumnWidth
    @State private var linkHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if let url = FuturesChartLink.url(for: row.instrument, quoteSymbol: row.quote?.symbol) {
                Link(destination: url) {
                    Text(row.instrument.name).font(.system(size: 13, weight: .semibold))
                        .underline(linkHovered)
                        .lineLimit(1).truncationMode(.middle).frame(height: 16)
                }.buttonStyle(MonitorContentButtonStyle())
                    .foregroundStyle(linkHovered ? Color.accentColor : Color.primary)
                    .onHover { linkHovered = $0 }
                    .help("\(row.instrument.name)：在\(row.instrument.dataSource.name)打开主连K线")
                    .accessibilityLabel("\(row.instrument.name)，打开\(row.instrument.dataSource.name)主连K线")
            } else {
                Text(row.instrument.name).font(.system(size: 13, weight: .semibold))
                    .lineLimit(1).truncationMode(.middle).frame(height: 16).help(row.instrument.name)
            }
            HStack(spacing: 5) {
                Text("主连").font(.system(size: 11)).foregroundStyle(.secondary)
                StatusBadge(status: row.status)
            }.fixedSize()
        }.frame(width: columnWidth - 16, height: MonitorLayout.rowContentHeight, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, verticalPadding)
            .accessibilityElement(children: .contain)
    }
}

/// Keeps data controls quiet at rest while making hover and press states visible.
struct MonitorContentButtonStyle: ButtonStyle {
    var minimumWidth: CGFloat = 0
    var minimumHeight: CGFloat = MonitorLayout.rowContentHeight

    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, minimumWidth: minimumWidth, minimumHeight: minimumHeight)
    }

    private struct Content: View {
        let configuration: ButtonStyle.Configuration
        let minimumWidth: CGFloat
        let minimumHeight: CGFloat
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovered = false

        var body: some View {
            configuration.label
                .frame(minWidth: minimumWidth, minHeight: minimumHeight)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.18 : (hovered ? 0.09 : 0)) : 0))
                }
                .onHover { hovered = $0 }
        }
    }
}
