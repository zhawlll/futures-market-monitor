import Foundation

enum BrokerReferenceParser {
    private static let exchanges = ["上海期货交易所": "SHFE", "大连商品交易所": "DCE",
        "郑州商品交易所": "CZCE", "上海国际能源交易中心": "INE", "中国金融期货交易所": "CFFEX",
        "中金所": "CFFEX", "广州期货交易所": "GFEX"]
    static func captures(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let text = text as NSString
        return regex.matches(in: text as String, range: NSRange(location: 0, length: text.length)).map { match in
            (1..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : text.substring(with: match.range(at: $0)) }
        }
    }
    static func clean(_ text: String) -> String {
        var value = text.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
        for (entity, replacement) in [("&nbsp;", " "), ("&#160;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&amp;", "&")] {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        return value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func multiplier(unit: String, minimumPrice: String) -> Double? {
        let unit = unit.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        if let match = captures("^([0-9.]+)元/点$", unit).first, let value = Double(match[0]), value > 0 { return value }
        guard let volume = captures("^([0-9.]+)(吨|千克|克|立方米|张|桶)/手$", unit).first,
              let amount = Double(volume[0]), amount > 0,
              let price = captures("元(?:（人民币）|\\(人民币\\))?/([0-9.]*)?(吨|千克|克|立方米|张|桶)", minimumPrice).first else { return nil }
        let divisor = price[0].isEmpty ? 1 : Double(price[0]) ?? 0
        guard divisor > 0 else { return nil }
        let weights: [String: Double] = ["吨": 1000, "千克": 1, "克": 0.001]
        if let from = weights[volume[1]], let to = weights[price[1]] { return amount * from / (divisor * to) }
        return volume[1] == price[1] ? amount / divisor : nil
    }
    static func contracts(_ data: Data, fetchedAt: Date = Date()) throws -> [String: ContractSpec] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["code"] as? Int == 10000,
              let sections = root["data"] as? [[String: Any]] else { throw QuoteError.invalidResponse }
        var result: [String: ContractSpec] = [:]
        for section in sections {
            guard let exchangeName = section["exchange"] as? String, let exchange = exchanges[exchangeName], let rows = section["rule"] as? [[String: Any]] else { continue }
            for row in rows {
                guard let code = row["VarietiesEN"] as? String, let unit = row["JYDW"] as? String,
                      let priceUnit = row["MinimumPrice"] as? String, let multiplier = multiplier(unit: unit, minimumPrice: priceUnit), multiplier.isFinite, multiplier > 0 else { continue }
                result[BrokerSnapshot.key(exchange: exchange, code: code)] = ContractSpec(multiplier: multiplier, tradingUnit: unit, priceUnit: priceUnit, fetchedAt: fetchedAt)
            }
        }
        guard !result.isEmpty else { throw QuoteError.empty }
        return result
    }
    static func margins(_ data: Data, fetchedAt: Date = Date()) throws -> [String: MarginTerms] {
        guard let html = String(data: data, encoding: .utf8), html.contains("公司保证金比例"),
              let table = captures("<table[^>]*id=[\"']jyrl_tb[\"'][^>]*>(.*?)</table>", html).first?.first else { throw QuoteError.invalidResponse }
        var result: [String: MarginTerms] = [:]
        var exchange: String?
        for row in captures("<tr\\b[^>]*>(.*?)</tr>", table) {
            var cells = captures("<td\\b[^>]*>(.*?)</td>", row[0]).map { clean($0[0]) }
            if cells.count == 8 { exchange = exchanges[cells.removeFirst()] }
            guard let exchange, cells.count == 7, cells[1].range(of: "^[A-Za-z_]+$", options: .regularExpression) != nil else { continue }
            let ratio = captures("^([0-9.]+)%$", cells[4]).first.flatMap { Double($0[0]) }.flatMap { $0 > 0 && $0 <= 100 ? $0 / 100 : nil }
            let text = cells[4].isEmpty ? "-" : cells[4]
            let exceptions = [cells[5], cells[6]].filter { !$0.isEmpty }.joined(separator: "；")
            result[BrokerSnapshot.key(exchange: exchange, code: cells[1])] = MarginTerms(ratio: ratio, text: text,
                mainContract: cells[1] + cells[2], exceptions: exceptions, fetchedAt: fetchedAt)
        }
        guard !result.isEmpty else { throw QuoteError.empty }
        return result
    }
    static func fees(_ data: Data, fetchedAt: Date = Date()) throws -> [String: FeeTerms] {
        guard let html = String(data: data, encoding: .utf8), html.contains("公司期货手续费标准（不高于以下标准）") else { throw QuoteError.invalidResponse }
        let publishedDate = captures("数据更新日期[：:]\\s*(\\d{4}-\\d{2}-\\d{2})", clean(html)).first?.first
        var result: [String: FeeTerms] = [:]
        var exchange: String?
        for row in captures("<tr\\b[^>]*>(.*?)</tr>", html) {
            var cells = captures("<td\\b[^>]*>(.*?)</td>", row[0]).map { $0[0] }
            if cells.count == 3 { exchange = exchanges[clean(cells.removeFirst())] }
            guard let exchange, cells.count == 2,
                  let code = captures("<span\\b[^>]*class=[\"']right[\"'][^>]*>(.*?)</span>", cells[0]).first.map({ clean($0[0]) }),
                  code.range(of: "^[A-Za-z_]+$", options: .regularExpression) != nil else { continue }
            let text = clean(cells[1])
            if !text.isEmpty { result[BrokerSnapshot.key(exchange: exchange, code: code)] = FeeTerms(text: text, publishedDate: publishedDate, fetchedAt: fetchedAt) }
        }
        guard !result.isEmpty else { throw QuoteError.empty }
        return result
    }
}
