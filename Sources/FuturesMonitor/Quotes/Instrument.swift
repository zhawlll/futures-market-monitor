import Foundation

struct Instrument: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let exchange: String
    let base: String

    var searchText: String { "\(name) \(exchange) \(id)".lowercased() }
    var dataSource: DataSource { id.hasPrefix("em:") ? .eastmoney : .sina }
    var eastMoneyMainCode: String? { dataSource == .eastmoney ? String(id.dropFirst(3)) : nil }
    var quoteSource: String { dataSource.quoteName }
    var canonicalName: String {
        let stripped = name.replacingOccurrences(of: "股指期货", with: "")
            .replacingOccurrences(of: "指数期货", with: "").replacingOccurrences(of: "期货", with: "")
        let aliases = ["沪银": "白银", "沪金": "黄金", "沪铜": "铜", "沪铝": "铝", "沪铅": "铅",
            "沪锌": "锌", "沪镍": "镍", "沪锡": "锡", "棕榈": "棕榈油", "沪深": "沪深300",
            "上证": "上证50", "中证500股指": "中证500", "中证1000股指": "中证1000",
            "二债": "2年期国债", "五债": "5年期国债", "十债": "10年期国债", "三十债": "30年期国债",
            "玉米淀粉": "淀粉", "郑醇": "甲醇", "菜籽油": "菜油", "液化石油气": "LPG",
            "大豆": "豆一", "天然橡胶": "橡胶", "燃料油": "燃油", "集运指数": "欧线集运"]
        return (aliases[stripped] ?? stripped).lowercased()
    }
    func counterpart(in catalog: [Instrument]) -> Instrument? {
        catalog.first { $0.id == id } ?? catalog.first {
            $0.canonicalName == canonicalName && ($0.exchange == exchange
                || Set([$0.exchange, exchange]) == Set(["SHFE", "INE"]))
        }
    }
}
