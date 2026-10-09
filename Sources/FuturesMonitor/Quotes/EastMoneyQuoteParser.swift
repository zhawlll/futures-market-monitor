import Foundation
import CoreFoundation

enum EastMoneyQuoteParser {
    static func parse(_ data: Data, expectedCode: String, fetchedAt: Date = Date()) throws -> Quote {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let row = root["qt"] as? [String: Any] else { throw QuoteError.invalidResponse }
        func number(_ key: String) -> Double? {
            let value: Double?
            if let text = row[key] as? String { value = Double(text) }
            else if let number = row[key] as? NSNumber { value = number.doubleValue }
            else { value = nil }
            return value?.isFinite == true ? value : nil
        }
        let parts = expectedCode.split(separator: ".")
        guard parts.count == 2, let symbol = row["dm"] as? String,
              symbol.lowercased() == String(parts[1]).lowercased(), symbol.lowercased().hasSuffix("m"),
              number("sc") == Double(parts[0]) else { throw QuoteError.missingContinuous }
        guard let price = number("p"), price > 0 else { throw QuoteError.invalidFields("最新价") }
        guard let epoch = number("utime"), epoch >= 946684800,
              epoch <= fetchedAt.timeIntervalSince1970 + 300 else {
            throw QuoteError.invalidFields("行情时间")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        let timestamp = Date(timeIntervalSince1970: epoch)
        let date = formatter.string(from: timestamp)
        formatter.dateFormat = "HH:mm:ss"
        let tick = formatter.string(from: timestamp)
        var values: [Metric: Double] = [.price: price]
        for (metric, key) in [(Metric.open, "o"), (.high, "h"), (.low, "l"), (.previousSettlement, "zjsj")] {
            if let value = number(key), value > 0 { values[metric] = value }
        }
        for (metric, key) in [(Metric.volume, "vol"), (.position, "ccl")] {
            if let value = number(key), value >= 0 { values[metric] = value }
        }
        if let settlement = values[.previousSettlement] {
            values[.change] = price - settlement
        }
        // Eastmoney's zdf is settlement-based. The monitor uses the previous
        // trading day's close instead, and never substitutes settlement for it.
        let previousClose = number("qrspj").flatMap { $0 > 0 ? $0 : nil }
        if let previousClose { values[.percent] = (price - previousClose) / previousClose }
        return Quote(symbol: symbol.uppercased(), date: date, tickTime: tick,
                     values: values, fetchedAt: fetchedAt, source: "东方财富", previousClose: previousClose)
    }
}
