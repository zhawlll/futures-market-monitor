import Foundation
import CoreFoundation

enum EastMoneyCatalogParser {
    struct Market { let id: String; let exchange: String }
    static func markets(_ data: Data) throws -> [Market] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw QuoteError.invalidResponse }
        let supported = Set(["SHFE", "DCE", "CZCE", "INE", "CFFEX", "GFEX"])
        let markets = rows.compactMap { row -> Market? in
            guard let id = row["mktid"] as? String, Int(id) != nil,
                  let exchange = row["mktshort"] as? String, supported.contains(exchange) else { return nil }
            return Market(id: id, exchange: exchange)
        }
        guard !markets.isEmpty else { throw QuoteError.empty }
        return markets
    }
    static func list(_ data: Data, exchange: String, expectedMarket: String) throws -> (instruments: [Instrument], total: Int, received: Int) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["list"] as? [[String: Any]], let total = root["total"] as? Int,
              total >= 0 else { throw QuoteError.invalidResponse }
        var instruments: [Instrument] = []
        for row in rows {
            guard let name = row["name"] as? String, let code = row["dm"] as? String,
                  code.range(of: "^[A-Za-z]+m$", options: [.regularExpression, .caseInsensitive]) != nil,
                  let market = row["sc"] as? Int, String(market) == expectedMarket else { continue }
            let display = name.hasSuffix("主连") ? String(name.dropLast(2)) : name
            instruments.append(Instrument(id: "em:\(market).\(code)", name: display, exchange: exchange, base: "eastmoney"))
        }
        return (instruments, total, rows.count)
    }
}
