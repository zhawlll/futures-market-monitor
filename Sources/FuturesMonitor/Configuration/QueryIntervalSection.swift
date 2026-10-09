import SwiftUI

struct QueryIntervalSection: View {
    @Binding var interval: Int
    @State private var intervalText: String

    init(interval: Binding<Int>) {
        _interval = interval
        _intervalText = State(initialValue: String(interval.wrappedValue))
    }
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Text("查询间隔").font(.headline).padding(.top, 6)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    TextField("查询间隔（秒）", text: $intervalText).frame(width: 68).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("queryInterval")
                        .onChange(of: intervalText) { _, text in interval = Int(text) ?? 0 }
                    Stepper("查询间隔", onIncrement: {
                        adjustInterval(increasing: true)
                    }, onDecrement: {
                        adjustInterval(increasing: false)
                    }).labelsHidden()
                        .accessibilityValue("\(interval) 秒")
                    Text("秒")
                }
                Text("最小 5 秒 · 每次查询完成后等待").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func adjustInterval(increasing: Bool) {
        interval = increasing ? QueryInterval.incremented(interval) : QueryInterval.decremented(interval)
        intervalText = String(interval)
    }
}
