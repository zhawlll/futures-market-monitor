import SwiftUI

struct InstrumentPicker: View {
    let store: MonitorStore
    let source: DataSource?
    @Binding var selected: [Instrument]
    @State private var search = ""
    @FocusState private var focused: Bool
    private var filtered: [Instrument] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.catalog(for: source).filter {
            term.isEmpty || $0.searchText.contains(term) || $0.name.applyingTransform(.toLatin, reverse: false)?.lowercased().contains(term) == true
        }
    }
    var body: some View {
        let matches = filtered
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索期货品种", text: $search).textFieldStyle(.plain).focused($focused)
                if !search.isEmpty {
                    Button("清空搜索", systemImage: "xmark.circle.fill") { search = "" }
                        .labelStyle(.iconOnly).buttonStyle(.plain)
                }
            }.padding(9).background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6))
            HStack {
                Text(search.isEmpty ? "全部支持品种" : "搜索结果").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(matches.count) 个").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(matches) { instrument in
                        HStack {
                            Toggle(instrument.name, isOn: Binding(
                                get: { selected.contains { $0.id == instrument.id } },
                                set: { enabled in
                                    if enabled { selected.append(instrument) }
                                    else { selected.removeAll { $0.id == instrument.id } }
                                }
                            )).toggleStyle(.checkbox)
                            Spacer()
                            Text(instrument.exchange).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 9).padding(.horizontal, 4)
                    }
                    if matches.isEmpty { Text("没有匹配的品种").foregroundStyle(.secondary).padding(30) }
                }
            }.frame(height: 270)
            Divider()
            HStack {
                Text("已选择 \(selected.count) 个品种").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }.padding(14).frame(maxWidth: .infinity).onAppear { focused = true }
    }
}
