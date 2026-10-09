import Foundation

enum QuoteParser {
    static func parse(_ data: Data, fetchedAt: Date = Date()) throws -> Quote {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw QuoteError.invalidResponse
        }
        guard !rows.isEmpty else { throw QuoteError.empty }
        // Sina's continuous codes are letters followed by ONE zero, e.g. LC0, IF0.
        guard let row = rows.first(where: {
            ($0["symbol"] as? String)?.range(of: "^[A-Za-z]+0$", options: .regularExpression) != nil
        }) else { throw QuoteError.missingContinuous }
        func number(_ key: String) -> Double? {
            let value: Double?
            if let string = row[key] as? String { value = Double(string) }
            else if let n = row[key] as? NSNumber { value = n.doubleValue }
            else { value = nil }
            return value?.isFinite == true ? value : nil
        }
        guard let price = number("trade"), price > 0 else { throw QuoteError.invalidFields("最新价") }
        guard let date = row["tradedate"] as? String,
              let tick = row["ticktime"] as? String,
              date.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil,
              tick.range(of: "^\\d{2}:\\d{2}:\\d{2}$", options: .regularExpression) != nil else {
            throw QuoteError.invalidFields("交易日期或行情时间")
        }
        let clock = DateFormatter()
        clock.locale = Locale(identifier: "en_US_POSIX")
        clock.timeZone = TimeZone(identifier: "Asia/Shanghai")
        clock.dateFormat = "yyyy-MM-dd HH:mm:ss"
        clock.isLenient = false
        guard clock.date(from: date + " " + tick) != nil else { throw QuoteError.invalidFields("交易日期或行情时间") }
        var values: [Metric: Double] = [.price: price]
        for (metric, key) in [(Metric.open, "open"), (.high, "high"), (.low, "low"), (.previousSettlement, "presettlement")] {
            if let value = number(key), value > 0 { values[metric] = value }
        }
        for (metric, key) in [(Metric.volume, "volume"), (.position, "position")] {
            if let value = number(key), value >= 0 { values[metric] = value }
        }
        if let settlement = values[.previousSettlement] {
            values[.change] = price - settlement
            values[.percent] = (price - settlement) / settlement
        }
        return Quote(symbol: row["symbol"] as! String, date: date, tickTime: tick,
                     values: values, fetchedAt: fetchedAt)
    }
}
