import Foundation
import Testing
@testable import FuturesMonitorCore

struct BrokerReferenceParserTests {
    @Test func parsesContractsAndSkipsUnknownOrIncompatibleUnits() throws {
        let data = try Fixtures.json(["code": 10000, "data": [
            ["exchange": "大连商品交易所", "rule": [
                ["VarietiesEN": "AA", "JYDW": "16吨/手", "MinimumPrice": "5元/吨"],
                ["VarietiesEN": "BB", "JYDW": "5吨/手", "MinimumPrice": "1元/500千克"],
                ["VarietiesEN": "BAD", "JYDW": "5吨/手", "MinimumPrice": "1元/桶"]
            ]],
            ["exchange": "中金所", "rule": [
                ["VarietiesEN": "CC", "JYDW": "300元/点", "MinimumPrice": "0.2点"]
            ]],
            ["exchange": "未知交易所", "rule": [
                ["VarietiesEN": "DD", "JYDW": "1吨/手", "MinimumPrice": "1元/吨"]
            ]]
        ]])
        let contracts = try BrokerReferenceParser.contracts(data, fetchedAt: Fixtures.fetchedAt)
        #expect(Set(contracts.keys) == ["DCE:AA", "DCE:BB", "CFFEX:CC"])
        #expect(contracts["DCE:AA"]?.multiplier == 16)
        #expect(contracts["DCE:BB"]?.multiplier == 10)
        #expect(contracts["CFFEX:CC"]?.multiplier == 300)
        #expect(contracts["DCE:AA"]?.fetchedAt == Fixtures.fetchedAt)
    }

    @Test func parsesMarginsAcrossMergedExchangeCells() throws {
        let data = Data("""
        <html>公司保证金比例<table id="jyrl_tb">
        <tr><td rowspan="2">大连商品交易所</td><td>测试甲</td><td>AA</td><td>9901</td><td>占位</td><td>20%</td><td>特殊甲</td><td>特殊乙</td></tr>
        <tr><td>测试乙</td><td>BB</td><td>9902</td><td>占位</td><td>12.5%</td><td></td><td></td></tr>
        <tr><td>广州期货交易所</td><td>测试丙</td><td>CC</td><td>9903</td><td>占位</td><td>100%</td><td></td><td></td></tr>
        </table></html>
        """.utf8)
        let margins = try BrokerReferenceParser.margins(data, fetchedAt: Fixtures.fetchedAt)
        #expect(Set(margins.keys) == ["DCE:AA", "DCE:BB", "GFEX:CC"])
        let first = try #require(margins["DCE:AA"])
        #expect(first.ratio == 0.2)
        #expect(first.mainContract == "AA9901")
        #expect(first.exceptions == "特殊甲；特殊乙")
        #expect(first.fetchedAt == Fixtures.fetchedAt)
        #expect(margins["DCE:BB"]?.ratio == 0.125)
        #expect(margins["GFEX:CC"]?.ratio == 1)
    }

    @Test func parsesFeesAcrossMergedExchangeCellsAndCleansMarkup() throws {
        let data = Data("""
        <html>公司期货手续费标准（不高于以下标准） 数据更新日期：2099-01-02
        <table>
        <tr><td rowspan="2">大连商品交易所</td><td>测试甲<span class="right">AA</span></td><td><b>人工费率甲</b>&nbsp;说明</td></tr>
        <tr><td>测试乙<span class='right'>BB</span></td><td>人工费率乙</td></tr>
        <tr><td>广州期货交易所</td><td>测试丙<span class="right">CC</span></td><td>人工费率丙</td></tr>
        </table></html>
        """.utf8)
        let fees = try BrokerReferenceParser.fees(data, fetchedAt: Fixtures.fetchedAt)
        #expect(Set(fees.keys) == ["DCE:AA", "DCE:BB", "GFEX:CC"])
        #expect(fees["DCE:AA"]?.text == "人工费率甲 说明")
        #expect(fees["DCE:BB"]?.text == "人工费率乙")
        #expect(fees["GFEX:CC"]?.publishedDate == "2099-01-02")
        #expect(fees["DCE:AA"]?.fetchedAt == Fixtures.fetchedAt)
    }

    @Test(arguments: ReferencePart.allCases)
    func rejectsInvalidPagesWithSpecificError(part: ReferencePart) {
        expectQuoteError(.invalidResponse) {
            switch part {
            case .contracts: _ = try BrokerReferenceParser.contracts(Data("{}".utf8))
            case .margins: _ = try BrokerReferenceParser.margins(Data("<html>error</html>".utf8))
            case .fees: _ = try BrokerReferenceParser.fees(Data("<html>error</html>".utf8))
            }
        }
    }

    @Test func emptyRecognizedContractResponseIsNotSuccess() throws {
        let data = try Fixtures.json(["code": 10000, "data": []])
        expectQuoteError(.empty) { _ = try BrokerReferenceParser.contracts(data) }
    }

    @Test func incompatibleUnitsAreNotGuessed() {
        #expect(BrokerReferenceParser.multiplier(unit: "5吨/手", minimumPrice: "1元/500千克") == 10)
        #expect(BrokerReferenceParser.multiplier(unit: "5吨/手", minimumPrice: "1元/桶") == nil)
        #expect(BrokerReferenceParser.multiplier(unit: "未知单位", minimumPrice: "1元/吨") == nil)
    }
}
