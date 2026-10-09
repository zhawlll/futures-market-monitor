import SwiftUI

struct ConfigurationView: View {
    let store: MonitorStore
    @State private var draft: MonitorConfiguration
    @State private var showPicker = false
    @State private var selections: [DataSource: [Instrument]] = [:]
    @State private var sourceNotice: String?
    let cancel: () -> Void
    let commit: (MonitorConfiguration) -> Void

    init(store: MonitorStore, cancel: @escaping () -> Void, commit: @escaping (MonitorConfiguration) -> Void) {
        self.store = store
        self.cancel = cancel
        self.commit = commit
        _draft = State(initialValue: store.configuration)
    }
    private var validation: String {
        if draft.dataSource == nil { return "请先选择数据源" }
        if draft.interval < 5 || draft.interval > 86400 { return "请输入 5–86400 秒之间的整数" }
        if draft.instruments.isEmpty || draft.metrics.isEmpty { return "请选择至少一个品种和一个指标" }
        return "\(draft.instruments.count) 个品种 · \(draft.metrics.count) 个指标"
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("监控配置").font(.system(size: 23, weight: .semibold))
                        Text("先选择数据源，再配置品种与指标").foregroundStyle(.secondary)
                    }
                    DataSourceSection(source: draft.dataSource, notice: sourceNotice, select: selectSource)
                    Divider()
                    InstrumentConfigurationSection(store: store, source: draft.dataSource, instruments: $draft.instruments, showPicker: $showPicker)
                        .disabled(draft.dataSource == nil)
                    Divider()
                    MetricConfigurationSection(source: draft.dataSource, metrics: $draft.metrics)
                        .disabled(draft.dataSource == nil)
                    Divider()
                    QueryIntervalSection(interval: $draft.interval).disabled(draft.dataSource == nil)
                }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack(spacing: 12) {
                Text(validation).font(.system(size: 12)).foregroundStyle((draft.interval < 5 || draft.interval > 86400) ? Color.red : Color.secondary)
                Spacer()
                Button("取消", action: cancel).keyboardShortcut(.cancelAction)
                Button("保存并开始监控") { commit(draft) }
                    .buttonStyle(.borderedProminent).disabled(!draft.valid)
                    .keyboardShortcut(.defaultAction)
            }.padding(20)
        }
        .frame(minWidth: 560, minHeight: 630)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func selectSource(_ source: DataSource) {
        guard draft.dataSource != source else { return }
        if let previous = draft.dataSource { selections[previous] = draft.instruments }
        let before = draft.instruments
        let mapped = selections[source] ?? before.compactMap { $0.counterpart(in: store.catalog(for: source)) }
        let missing = before.filter { $0.counterpart(in: store.catalog(for: source)) == nil }.map(\.name)
        sourceNotice = missing.isEmpty ? nil : "当前数据源不支持：" + missing.joined(separator: "、") + "，请重新选择品种"
        draft.dataSource = source
        draft.instruments = mapped
        showPicker = false
        Task { await store.loadCatalog(source) }
    }

}
