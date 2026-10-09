import SwiftUI

struct StatusBadge: View {
    let status: RowStatus
    private var color: Color { status.isFailure ? .red : (status == .success ? .green : .secondary) }
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.isFailure ? "exclamationmark.triangle" : (status == .success ? "checkmark" : "clock"))
            Text(status.label)
        }.font(.system(size: 10, weight: .medium)).foregroundStyle(color).frame(height: 12)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(color.opacity(0.09)).clipShape(Capsule())
    }
}
