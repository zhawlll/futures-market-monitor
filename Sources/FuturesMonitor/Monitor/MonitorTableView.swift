import SwiftUI

struct MonitorTableView: View {
    let store: MonitorStore
    @State private var horizontalOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = MonitorLayout.effectiveInstrumentColumnWidth(store.instrumentColumnWidth, availableWidth: geometry.size.width)
            let viewportWidth = max(1, geometry.size.width - columnWidth - 1)
            let contentWidth = max(MonitorLayout.metricsWidth(store.configuration.metrics), viewportWidth)
            let scrollerHeight: CGFloat = contentWidth > viewportWidth ? 15 : 0
            let padding = MonitorLayout.rowPadding(availableHeight: geometry.size.height - scrollerHeight, rowCount: store.rows.count)
            let rowsHeight = MonitorLayout.tableHeight(rowCount: store.rows.count, padding: padding) - MonitorLayout.headerHeight
            // A pinned section header stays above both columns. One vertical
            // container keeps the rows aligned; only metric rows scroll horizontally.
            ScrollView(.vertical) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: 0) {
                                ForEach(store.rows) { row in
                                    InstrumentCellView(row: row, verticalPadding: padding, columnWidth: columnWidth)
                                    Divider()
                                }
                            }.frame(width: columnWidth)
                            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1, height: rowsHeight)
                            ScrollView(.horizontal) {
                                VStack(spacing: 0) {
                                    ForEach(store.rows) { row in
                                        QuoteRowView(row: row, metrics: store.configuration.metrics, verticalPadding: padding, references: store.references)
                                        Divider()
                                    }
                                }.frame(width: contentWidth, height: rowsHeight + scrollerHeight, alignment: .topLeading)
                                    .background(HorizontalScrollObserver { horizontalOffset = $0 })
                            }
                                .frame(width: viewportWidth, height: rowsHeight + scrollerHeight)
                        }.frame(width: geometry.size.width)
                    } header: {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text("品种").font(.system(size: 12)).foregroundStyle(.secondary)
                                    .frame(width: columnWidth - 16, height: 16, alignment: .leading)
                                    .padding(.horizontal, 8).padding(.vertical, 12)
                                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1, height: 40)
                                MonitorTableHeader(metrics: store.configuration.metrics, source: store.configuration.dataSource)
                                    .frame(width: contentWidth, alignment: .leading)
                                    .offset(x: horizontalOffset)
                                    .frame(width: viewportWidth, alignment: .leading)
                                    .clipped()
                            }
                            Divider()
                        }.background(Color(nsColor: .windowBackgroundColor))
                            .overlay(alignment: .topLeading) {
                                InstrumentColumnResizeHandle(store: store, effectiveWidth: columnWidth, availableWidth: geometry.size.width)
                                    .frame(width: 10, height: MonitorLayout.headerHeight - 1)
                                    .offset(x: columnWidth - 4)
                            }
                            .zIndex(1)
                    }
                }.frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
    }
}
