import SwiftUI

struct DataSourceSection: View {
    let source: DataSource?
    let notice: String?
    let select: (DataSource) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("数据源").font(.headline)
            HStack(spacing: 12) {
                ForEach(DataSource.allCases) { candidate in
                    Button { select(candidate) } label: {
                        HStack {
                            Image(systemName: source == candidate ? "checkmark.circle.fill" : "circle")
                            Text(candidate.name)
                            Spacer()
                        }.padding(12).frame(maxWidth: .infinity)
                            .background(source == candidate ? Color.accentColor.opacity(0.1) : Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay { RoundedRectangle(cornerRadius: 7).stroke(source == candidate ? Color.accentColor : Color.secondary.opacity(0.3)) }
                    }.buttonStyle(.plain).accessibilityLabel(candidate.name)
                        .accessibilityValue(source == candidate ? "已选择" : "未选择")
                }
            }
            Text("不同数据源的主连换月口径可能不同").font(.caption).foregroundStyle(.secondary)
            if let notice { Text(notice).font(.caption).foregroundStyle(.orange) }
        }
    }
}
