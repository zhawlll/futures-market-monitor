import Foundation
import CoreFoundation

final class FuturesQuoteService: QuoteProviding {
    private let session: URLSession
    private let gate = QueryGate()
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }
    private func load(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 FuturesMonitor/1.0", forHTTPHeaderField: "User-Agent")
        let referer = url.host?.hasSuffix("eastmoney.com") == true
            ? "https://quote.eastmoney.com/" : "https://vip.stock.finance.sina.com.cn/"
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw QuoteError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw QuoteError.http(response.statusCode) }
        return data
    }
    func quote(for instrument: Instrument) async throws -> Quote {
        try await gate.enter(for: instrument.id)
        if let code = instrument.eastMoneyMainCode {
            var url = URLComponents(string: "https://futsseapi.eastmoney.com/static/\(code.replacingOccurrences(of: ".", with: "_"))_qt")!
            // These are the public parameters and unscaled fields used by the
            // official Eastmoney futures page, not the stock endpoint's f-fields.
            url.queryItems = [
                URLQueryItem(name: "token", value: "1101ffec61617c99be287c1bec3085ff"),
                URLQueryItem(name: "field", value: "name,sc,dm,p,zsjd,zdf,zde,utime,o,zjsj,qrspj,h,l,vol,ccl")
            ]
            return try EastMoneyQuoteParser.parse(await load(url.url!), expectedCode: code)
        }
        var url = URLComponents(string: "https://vip.stock.finance.sina.com.cn/quotes_service/api/json_v2.php/Market_Center.getHQFuturesData")!
        url.queryItems = ["page": "1", "num": "100", "sort": "position", "asc": "0",
                          "node": instrument.id, "base": instrument.base].map { URLQueryItem(name: $0.key, value: $0.value) }
        return try QuoteParser.parse(await load(url.url!))
    }
    func catalog(source: DataSource) async throws -> [Instrument] {
        if source == .sina {
            try await gate.enter(for: "catalog:sina")
            let data = try await load(URL(string: "https://vip.stock.finance.sina.com.cn/quotes_service/view/js/qihuohangqing.js")!)
            return try CatalogParser.parse(data)
        }
        try await gate.enter(for: "catalog:eastmoney:markets")
        let markets = try EastMoneyCatalogParser.markets(await load(URL(string: "https://futsse-static.eastmoney.com/redis?msgid=gnweb")!))
        var result: [Instrument] = []
        for market in markets {
            var page = 0
            var total = 1
            var received = 0
            while received < total {
                try await gate.enter(for: "catalog:eastmoney:\(market.id):\(page)")
                var url = URLComponents(string: "https://futsseapi.eastmoney.com/list/main/\(market.id)")!
                url.queryItems = ["token": "1101ffec61617c99be287c1bec3085ff", "pageSize": "100",
                    "pageIndex": String(page), "orderBy": "zdf", "sort": "desc", "field": "name,sc,dm"]
                    .map { URLQueryItem(name: $0.key, value: $0.value) }
                let data = try await load(url.url!)
                let parsed = try EastMoneyCatalogParser.list(data, exchange: market.exchange, expectedMarket: market.id)
                result.append(contentsOf: parsed.instruments)
                total = parsed.total
                received += parsed.received
                guard parsed.received > 0 || total == 0 else { throw QuoteError.invalidResponse }
                page += 1
            }
        }
        guard !result.isEmpty else { throw QuoteError.empty }
        var ids = Set<String>()
        return result.filter { ids.insert($0.id).inserted }
    }
}
