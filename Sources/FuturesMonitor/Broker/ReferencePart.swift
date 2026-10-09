import Foundation

enum ReferencePart: String, CaseIterable, Hashable {
    case contracts, margins, fees
    var name: String {
        switch self {
        case .contracts: return "合约单位"
        case .margins: return "保证金比例"
        case .fees: return "手续费说明"
        }
    }
    var url: URL {
        URL(string: self == .contracts
            ? "https://qhhqzl.eastmoney.com/marketFutuWeb/primaryStation/getTradeRuleListV1"
            : "https://portal.eastmoneyfutures.com/pages/service/\(self == .margins ? "jyts" : "sxf").html")!
    }
}
