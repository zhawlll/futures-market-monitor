import SwiftUI

struct MonitorView: View {
    let store: MonitorStore
    let configure: () -> Void
    let pin: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Text("期货行情监控").font(.system(size: 14, weight: .semibold))
                if let source = store.configuration.dataSource { Text(source.name).font(.caption).foregroundStyle(.secondary) }
                if store.isDemo { Text("演示数据").font(.caption).foregroundStyle(.orange) }
                Spacer()
                Button(store.paused ? "继续查询" : "暂停查询", systemImage: store.paused ? "play.fill" : "pause.fill") { store.togglePause() }
                    .labelStyle(.iconOnly)
                    .help(store.paused ? "继续查询" : "暂停查询")
                    .accessibilityLabel(store.paused ? "继续查询" : "暂停查询")
                Button(store.configuration.pinned ? "取消置顶" : "置顶窗口", systemImage: store.configuration.pinned ? "pin.fill" : "pin", action: pin)
                    .labelStyle(.iconOnly)
                    .help(store.configuration.pinned ? "取消置顶" : "置顶窗口")
                    .accessibilityLabel(store.configuration.pinned ? "取消置顶" : "置顶窗口")
                Button("监控配置", systemImage: "gearshape", action: configure).labelStyle(.iconOnly).help("监控配置").accessibilityLabel("监控配置")
            }.buttonStyle(MonitorContentButtonStyle(minimumWidth: 28, minimumHeight: 28))
                .padding(.horizontal, 15).padding(.vertical, 7)
            Divider()
            if store.configuration.instruments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("尚未配置监控品种")
                    Button("打开配置", action: configure).buttonStyle(.borderedProminent)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MonitorTableView(store: store)
            }
            Divider()
            HStack {
                Text(store.summary).lineLimit(1)
                Spacer(minLength: 8)
                Text("间隔 \(store.configuration.interval) 秒").lineLimit(1)
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 15).padding(.vertical, 9)
        }.frame(minWidth: 360, minHeight: 144).background(Color(nsColor: .windowBackgroundColor))
    }

}
