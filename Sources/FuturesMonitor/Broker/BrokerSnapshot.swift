import Foundation

struct BrokerSnapshot {
    var contracts: [String: ContractSpec] = [:]
    var margins: [String: MarginTerms] = [:]
    var fees: [String: FeeTerms] = [:]
    var errors: [ReferencePart: String] = [:]

    mutating func apply(_ update: BrokerReferenceUpdate) {
        if let contracts = update.contracts { self.contracts = contracts }
        if let margins = update.margins { self.margins = margins }
        if let fees = update.fees { self.fees = fees }
        errors = update.errors
    }
    static func key(exchange: String, code: String) -> String {
        let product = code.uppercased().replacingOccurrences(of: "_", with: "")
        // The legacy Sina directory groups INE commodities under SHFE.
        let exchange = exchange == "SHFE" && ["SC", "LU", "NR", "BC", "EC"].contains(product) ? "INE" : exchange
        return exchange + ":" + product
    }
    func key(for row: MonitorRow) -> String? {
        guard let quote = row.quote,
              quote.symbol.range(of: "^[A-Za-z]+[0m]$", options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        return Self.key(exchange: row.instrument.exchange, code: String(quote.symbol.dropLast()))
    }
    func formatted(_ metric: Metric, row: MonitorRow) -> String {
        // Initial quote failures keep every displayed metric as a placeholder.
        guard let key = key(for: row) else { return "-" }
        switch metric {
        case .lotValue:
            guard let amount = lotValue(row: row, key: key) else { return "-" }
            return Self.number(amount, decimals: 2)
        case .lotMargin:
            guard let amount = lotValue(row: row, key: key), let ratio = margins[key]?.ratio,
                  ratio.isFinite, ratio > 0, ratio <= 1 else { return "-" }
            return Self.number(amount * ratio, decimals: 2)
        case .marginRatio:
            guard let terms = margins[key] else { return "-" }
            return terms.ratio.map { Self.number($0 * 100, decimals: 2) + "%" } ?? terms.text
        case .feeDescription: return fees[key]?.text ?? "-"
        default: return row.quote?.formatted(metric) ?? "-"
        }
    }
    private func lotValue(row: MonitorRow, key: String) -> Double? {
        guard let price = row.quote?.values[.price], price.isFinite, price > 0,
              let multiplier = contracts[key]?.multiplier, multiplier.isFinite, multiplier > 0 else { return nil }
        let amount = price * multiplier
        return amount.isFinite && amount > 0 ? amount : nil
    }
    static func number(_ value: Double, decimals: Int) -> String {
        guard value.isFinite else { return "-" }
        return value.formatted(
            .number.locale(Locale(identifier: "en_US"))
                .precision(.fractionLength(0...max(0, decimals)))
        )
    }
    func error(for metric: Metric) -> String? {
        let messages = metric.referenceParts.compactMap { part in errors[part].map { part.name + "：" + $0 } }
        return messages.isEmpty ? nil : messages.joined(separator: "；")
    }
    func details(_ metric: Metric, row: MonitorRow) -> String {
        var lines = [metric == .lotValue ? "1手价格为一手合约总价值，不是保证金" : "东方财富期货 · 公司公示参考标准"]
        if let key = key(for: row) {
            if metric == .lotValue, let spec = contracts[key] {
                lines += ["计算：最新价 × \(Self.number(spec.multiplier, decimals: 6))",
                    "交易单位：\(spec.tradingUnit)", "最小变动价位：\(spec.priceUnit)",
                    "资料抓取：\(spec.fetchedAt.formatted(date: .numeric, time: .standard))"]
            } else if metric == .lotMargin {
                lines.append("计算：1手价格 × 公司保证金比例（参考金额）")
                if let spec = contracts[key] {
                    lines += ["合约乘数：\(Self.number(spec.multiplier, decimals: 6))", "交易单位：\(spec.tradingUnit)",
                        "合约资料抓取：\(spec.fetchedAt.formatted(date: .numeric, time: .standard))"]
                } else { lines.append("尚未获取有效合约乘数") }
                if let terms = margins[key] {
                    lines += ["公司保证金比例：\(terms.text)", "官网参考主力：\(terms.mainContract)",
                        "保证金资料抓取：\(terms.fetchedAt.formatted(date: .numeric, time: .standard))"]
                    if !terms.exceptions.isEmpty { lines.append("特殊合约/备注：\(terms.exceptions)") }
                    if terms.ratio == nil { lines.append("保证金比例无法转换为数值，参考金额显示为 -") }
                } else { lines.append("尚未获取有效保证金比例") }
                lines += ["官网保证金表未标注发布时间", "主连参考金额；特殊月份合约和账户实际占用可能不同，以结算单为准"]
            } else if metric == .marginRatio, let terms = margins[key] {
                lines += ["公司保证金比例：\(terms.text)", "官网参考主力：\(terms.mainContract)"]
                if !terms.exceptions.isEmpty { lines.append("特殊合约/备注：\(terms.exceptions)") }
                lines += ["官网未标注发布时间", "资料抓取：\(terms.fetchedAt.formatted(date: .numeric, time: .standard))",
                    "主连不是可交易合约，具体月份合约可能适用特殊比例；实际以账户结算单为准"]
            } else if metric == .feeDescription, let terms = fees[key] {
                lines += [terms.text, "公示日期：\(terms.publishedDate ?? "未标注")",
                    "资料抓取：\(terms.fetchedAt.formatted(date: .numeric, time: .standard))",
                    "官网公布为收费上限，实际账户费率以结算单为准；申报费等另行收取"]
            } else { lines.append("尚未获取此品种的有效资料") }
        } else { lines.append("尚未获取有效主连行情") }
        if let error = error(for: metric) {
            let cached = formatted(metric, row: row) != "-"
            lines.append("资料更新失败：\(error)；\(cached ? "保留上次成功资料" : "暂无有效缓存")")
        }
        lines.append("资料每30分钟刷新，失败后每60秒重试")
        return lines.joined(separator: "\n")
    }
}
