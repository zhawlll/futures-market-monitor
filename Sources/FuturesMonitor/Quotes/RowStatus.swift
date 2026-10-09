import Foundation

enum RowStatus: Equatable {
    case waiting, success, failed, unavailable
    var label: String {
        switch self {
        case .waiting: return "查询中"
        case .success: return "正常"
        case .failed: return "更新失败"
        case .unavailable: return "未获取"
        }
    }
    var isFailure: Bool { self == .failed || self == .unavailable }
}
