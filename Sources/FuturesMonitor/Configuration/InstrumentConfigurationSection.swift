import SwiftUI

struct InstrumentConfigurationSection: View {
    let store: MonitorStore
    let source: DataSource?
    @Binding var instruments: [Instrument]
    @Binding var showPicker: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("期货种类").font(.headline)
                Spacer()
                Button("全选") {
                    let selected = Set(instruments.map(\.id))
                    instruments.append(contentsOf: store.catalog(for: source).filter { !selected.contains($0.id) })
                }
                .disabled(store.catalog(for: source).allSatisfy { instrument in
                    instruments.contains { $0.id == instrument.id }
                })
                .help("选中当前数据源支持的全部品种，不受搜索筛选影响")
                .accessibilityIdentifier("selectAllInstruments")
                Button("取消全选") { instruments.removeAll() }
                    .disabled(instruments.isEmpty)
                    .accessibilityIdentifier("deselectAllInstruments")
            }
            Button { showPicker.toggle() } label: {
                HStack {
                    Text(instruments.isEmpty ? "请选择期货种类" : "已选择 \(instruments.count) 个品种")
                        .foregroundStyle(instruments.isEmpty ? Color.secondary : Color.primary)
                    Spacer()
                    Image(systemName: showPicker ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
                }.padding(11).background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay { RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.3)) }
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityIdentifier("instrumentPicker")
            if showPicker {
                InstrumentPicker(store: store, source: source, selected: $instruments)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)) }
            }
            if !instruments.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(instruments.enumerated()), id: \.element.id) { index, instrument in
                        HStack(spacing: 9) {
                            Text(instrument.name)
                            Text(instrument.exchange).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("上移 \(instrument.name)", systemImage: "arrow.up") { move(instrument, by: -1) }
                                .labelStyle(.iconOnly)
                                .disabled(index == 0).help("上移")
                            Button("下移 \(instrument.name)", systemImage: "arrow.down") { move(instrument, by: 1) }
                                .labelStyle(.iconOnly)
                                .disabled(index == instruments.count - 1).help("下移")
                            Button("移除 \(instrument.name)", systemImage: "xmark") { remove(instrument) }
                                .labelStyle(.iconOnly)
                                .help("移除 \(instrument.name)")
                        }.buttonStyle(.borderless).padding(.vertical, 3)
                    }
                }.padding(10).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 7))
            }
            HStack {
                Text("行情类型：主力连续").foregroundStyle(.secondary)
                Spacer()
                if let source = source, store.loadingSources.contains(source) { ProgressView().controlSize(.small) }
                Button("更新支持品种列表", systemImage: "arrow.clockwise", action: refreshCatalog)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless).help("更新支持品种列表")
                    .disabled(source.map { store.loadingSources.contains($0) } ?? true)
            }.font(.system(size: 12))
            if let source = source, let note = store.catalogNotes[source] {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func move(_ instrument: Instrument, by offset: Int) {
        guard let index = instruments.firstIndex(where: { $0.id == instrument.id }) else { return }
        let destination = index + offset
        guard instruments.indices.contains(destination) else { return }
        instruments.swapAt(index, destination)
    }
    private func remove(_ instrument: Instrument) {
        instruments.removeAll { $0.id == instrument.id }
    }
    private func refreshCatalog() {
        Task { await store.loadCatalog(source) }
    }
}
