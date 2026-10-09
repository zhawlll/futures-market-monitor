import Foundation
import Testing
@testable import FuturesMonitorCore

struct CatalogParserTests {
    @Test func bundledSinaCatalogMatchesEncodedMapping() throws {
        let catalog = try Fixtures.catalog("catalog")
        let data = try Data(contentsOf: Fixtures.root.appendingPathComponent("Tests/Fixtures/catalog-sina.js"))
        #expect(catalog.count >= 70)
        #expect(Set(catalog.map(\.id)).count == catalog.count)
        #expect(try CatalogParser.parse(data) == catalog)
    }

    @Test func bundledEastMoneyCatalogRoutesCounterparts() throws {
        let catalog = try Fixtures.catalog("catalog-eastmoney")
        #expect(catalog.count == 90)
        #expect(Set(catalog.map(\.id)).count == 90)
        let lh = try #require(Fixtures.lh.counterpart(in: catalog))
        let lc = try #require(Fixtures.lc.counterpart(in: catalog))
        #expect(Fixtures.lh.eastMoneyMainCode == nil)
        #expect(lh.eastMoneyMainCode == "114.lhm")
        #expect(lc.eastMoneyMainCode == "225.lcm")
    }
}

struct EastMoneyCatalogParserTests {
    @Test func filtersUnsupportedAndInvalidMarkets() throws {
        let data = try Fixtures.json([
            ["mktid": "114", "mktshort": "DCE"],
            ["mktid": "225", "mktshort": "GFEX"],
            ["mktid": "bad", "mktshort": "SHFE"],
            ["mktid": "999", "mktshort": "UNKNOWN"]
        ])
        let markets = try EastMoneyCatalogParser.markets(data)
        #expect(markets.map(\.id) == ["114", "225"])
        #expect(markets.map(\.exchange) == ["DCE", "GFEX"])
    }

    @Test func selectsMainContinuousContractsAndRetainsPagingCounts() throws {
        let data = try Fixtures.json(["total": 8, "list": [
            ["name": "测试甲主连", "dm": "aam", "sc": 114],
            ["name": "测试甲月份", "dm": "aa2701", "sc": 114],
            ["name": "其他市场主连", "dm": "bbm", "sc": 113],
            ["name": "测试乙主连", "dm": "CCM", "sc": 114]
        ]])
        let result = try EastMoneyCatalogParser.list(data, exchange: "DCE", expectedMarket: "114")
        #expect(result.instruments.map(\.id) == ["em:114.aam", "em:114.CCM"])
        #expect(result.instruments.map(\.name) == ["测试甲", "测试乙"])
        #expect(result.instruments.allSatisfy { $0.exchange == "DCE" && $0.dataSource == .eastmoney })
        #expect(result.total == 8)
        #expect(result.received == 4)
    }

    @Test func rejectsMalformedShapeAndEmptySupportedMarkets() {
        expectQuoteError(.invalidResponse) { _ = try EastMoneyCatalogParser.markets(Data("{}".utf8)) }
        expectQuoteError(.empty) { _ = try EastMoneyCatalogParser.markets(Data("[]".utf8)) }
        expectQuoteError(.invalidResponse) {
            _ = try EastMoneyCatalogParser.list(Data("{}".utf8), exchange: "DCE", expectedMarket: "114")
        }
    }
}
