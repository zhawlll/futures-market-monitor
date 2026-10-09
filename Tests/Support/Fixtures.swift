import Foundation
@testable import FuturesMonitorCore

// Artificial inputs only; no captured upstream responses or current market values.
enum Fixtures {
    static let fetchedAt = Date(timeIntervalSince1970: 1791430260)
    static let lc = Instrument(id: "lc_qh", name: "碳酸锂", exchange: "GFEX", base: "gfuturesindex")
    static let si = Instrument(id: "si_qh", name: "工业硅", exchange: "GFEX", base: "gfuturesindex")
    static let lh = Instrument(id: "lh_qh", name: "生猪", exchange: "DCE", base: "futures")
    static let emLC = Instrument(id: "em:225.lcm", name: "碳酸锂", exchange: "GFEX", base: "eastmoney")
    static let emLH = Instrument(id: "em:114.lhm", name: "生猪", exchange: "DCE", base: "eastmoney")
    static let sinaRows: [[String: Any]] = [
        ["symbol": "LC2701", "trade": "999999", "position": "99999999", "tradedate": "2026-10-08", "ticktime": "10:08:00"],
        ["symbol": "LC0", "trade": "123200", "presettlement": "118820", "position": "410617", "volume": "0", "open": "0", "tradedate": "2026-10-08", "ticktime": "10:07:33"]
    ]
    static var eastMoneyRow: [String: Any] {
        ["dm": "lhm", "sc": 114, "p": 10410.0, "h": 10555.0, "l": 10375.0,
         "o": 10490.0, "zjsj": 10590.0, "qrspj": 10680.0, "zdf": -1.7,
         "utime": 1791430200, "vol": 75807, "ccl": 126817]
    }
    static func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
    static func eastMoneyQuote(_ row: [String: Any] = eastMoneyRow) throws -> Quote {
        try EastMoneyQuoteParser.parse(json(["qt": row]), expectedCode: "114.lhm", fetchedAt: fetchedAt)
    }
    static func quote(for instrument: Instrument, price: Double = 123200, time: String = "10:07:33") -> Quote {
        Quote(symbol: instrument.eastMoneyMainCode?.components(separatedBy: ".").last?.uppercased() ?? "LC0",
              date: "2026-10-08", tickTime: time, values: [.price: price], fetchedAt: fetchedAt,
              source: instrument.quoteSource)
    }
    static let referenceUpdate = BrokerReferenceUpdate(
        contracts: [
            "DCE:LH": ContractSpec(multiplier: 16, tradingUnit: "16吨/手", priceUnit: "5元/吨", fetchedAt: fetchedAt),
            "GFEX:LC": ContractSpec(multiplier: 1, tradingUnit: "1吨/手", priceUnit: "20元/吨", fetchedAt: fetchedAt)
        ],
        margins: [
            "DCE:LH": MarginTerms(ratio: 0.2, text: "20%", mainContract: "LH9901", exceptions: "", fetchedAt: fetchedAt),
            "GFEX:LC": MarginTerms(ratio: 0.34, text: "34%", mainContract: "LC9901", exceptions: "", fetchedAt: fetchedAt)
        ],
        fees: ["DCE:LH": FeeTerms(text: "测试费率", publishedDate: nil, fetchedAt: fetchedAt)]
    )

    // Resolve checked-in catalogs relative to this source file, never the process cwd.
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static func catalog(_ name: String) throws -> [Instrument] {
        try JSONDecoder().decode([Instrument].self, from: Data(contentsOf: root.appendingPathComponent("Resources/\(name).json")))
    }
}
