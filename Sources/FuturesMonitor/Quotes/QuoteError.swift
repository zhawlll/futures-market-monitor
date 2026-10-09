import Foundation

enum QuoteError: LocalizedError, Equatable {
    case invalidResponse, http(Int), empty, missingContinuous, invalidFields(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "数据源返回了无法解析的响应"
        case .http(let code): return "数据源响应异常（HTTP \(code)）"
        case .empty: return "数据源暂未返回行情"
        case .missingContinuous: return "数据源未返回该品种的主力连续行情"
        case .invalidFields(let field): return "行情缺少有效的\(field)"
        }
    }
}
