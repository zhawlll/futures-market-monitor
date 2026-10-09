import Foundation

enum Metric: String, Codable, CaseIterable, Identifiable {
    case price, percent, change, open, high, low, previousSettlement, volume, position, marginRatio, lotValue, lotMargin, feeDescription
    var id: String { rawValue }
    var title: String {
        switch self {
        case .price: return "最新价"
        case .percent: return "涨跌幅"
        case .change: return "涨跌额"
        case .open: return "今开"
        case .high: return "最高"
        case .low: return "最低"
        case .previousSettlement: return "昨结算"
        case .volume: return "成交量"
        case .position: return "持仓量"
        case .marginRatio: return "保证金比例"
        case .lotValue: return "1手价格"
        case .lotMargin: return "一手保证金"
        case .feeDescription: return "手续费说明"
        }
    }
    var width: CGFloat {
        self == .feeDescription ? 180 : 100
    }
    var referencePart: ReferencePart? {
        switch self {
        case .marginRatio, .lotMargin: return .margins
        case .lotValue: return .contracts
        case .feeDescription: return .fees
        default: return nil
        }
    }
    var referenceParts: [ReferencePart] {
        if self == .lotMargin { return [.contracts, .margins] }
        return referencePart.map { [$0] } ?? []
    }
    func title(for source: DataSource?) -> String {
        if self == .lotValue { return "1手价格（元）" }
        if self == .lotMargin { return "一手保证金（元）" }
        guard source == .eastmoney else { return title }
        if self == .percent { return "涨跌幅（昨收）" }
        if self == .change { return "涨跌额（昨结）" }
        return title
    }
}
