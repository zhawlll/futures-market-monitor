import Foundation

enum DataSource: String, Codable, CaseIterable, Identifiable {
    case eastmoney, sina
    var id: String { rawValue }
    var name: String { self == .eastmoney ? "东方财富" : "新浪" }
    var quoteName: String { self == .eastmoney ? "东方财富" : "新浪财经" }
}
