import Foundation
import Testing
@testable import FuturesMonitorCore

struct QuoteParserTests {
    @Test func selectsContinuousQuoteAndUsesSettlement() throws {
        let quote = try QuoteParser.parse(Fixtures.json(Fixtures.sinaRows), fetchedAt: Fixtures.fetchedAt)
        #expect(quote.symbol == "LC0")
        #expect(quote.values[.price] == 123200)
        #expect(quote.formatted(.percent) == "+3.69%")
        #expect(quote.values[.change] == 4380)
        #expect(quote.formatted(.open) == "-")
        #expect(quote.formatted(.volume) == "0")
    }

    @Test func rejectsEmptyResponse() {
        expectQuoteError(.empty) { _ = try QuoteParser.parse(Data("[]".utf8)) }
    }

    @Test func rejectsResponseWithoutContinuousQuote() throws {
        let data = try Fixtures.json([Fixtures.sinaRows[0]])
        expectQuoteError(.missingContinuous) { _ = try QuoteParser.parse(data) }
    }

    @Test func rejectsMalformedJSON() {
        do {
            _ = try QuoteParser.parse(Data("not json".utf8))
            Issue.record("Malformed JSON must fail decoding")
        } catch {
            #expect((error as NSError).domain == NSCocoaErrorDomain)
            #expect((error as NSError).code == 3840)
        }
    }
}

struct EastMoneyQuoteParserTests {
    @Test func preservesSourceTimestampAndIndependentBaselines() throws {
        let quote = try Fixtures.eastMoneyQuote()
        #expect(quote.symbol == "LHM")
        #expect(quote.source == "东方财富")
        #expect(quote.values[.price] == 10410)
        #expect(quote.date == "2026-10-08")
        #expect(quote.tickTime == "11:30:00")
        #expect(quote.values[.volume] == 75807)
        #expect(quote.values[.position] == 126817)
        #expect(quote.values[.previousSettlement] == 10590)
        #expect(quote.values[.change] == -180)
        #expect(quote.previousClose == 10680)
        #expect(quote.formatted(.percent) == "-2.53%")
    }

    @Test(arguments: ["null", "0", "-1", "invalid", "nan", "missing"])
    func invalidCloseDoesNotFallBackToSettlement(value: String) throws {
        var row = Fixtures.eastMoneyRow
        switch value {
        case "null": row["qrspj"] = NSNull()
        case "missing": row.removeValue(forKey: "qrspj")
        default: row["qrspj"] = value
        }
        let quote = try Fixtures.eastMoneyQuote(row)
        #expect(quote.formatted(.percent) == "-")
        #expect(quote.previousClose == nil)
        #expect(quote.values[.price] == 10410)
        #expect(quote.values[.change] == -180)
    }

    @Test func missingSettlementDoesNotAffectPercent() throws {
        var row = Fixtures.eastMoneyRow
        row.removeValue(forKey: "zjsj")
        let quote = try Fixtures.eastMoneyQuote(row)
        #expect(quote.formatted(.percent) == "-2.53%")
        #expect(quote.formatted(.change) == "-")
    }

    @Test(arguments: [(101.0, "+1.00%", -9.0), (100.0, "0.00%", -10.0)])
    func acceptsStringClose(price: Double, percent: String, change: Double) throws {
        var row = Fixtures.eastMoneyRow
        row["p"] = price
        row["qrspj"] = "100"
        row["zjsj"] = 110
        let quote = try Fixtures.eastMoneyQuote(row)
        #expect(quote.formatted(.percent) == percent)
        #expect(quote.values[.change] == change)
    }

    @Test(arguments: ["dm", "sc", "utime", "p"])
    func rejectsSpecificInvalidFields(field: String) throws {
        var row = Fixtures.eastMoneyRow
        let expected: QuoteError
        switch field {
        case "dm": row[field] = "lh2611"; expected = .missingContinuous
        case "sc": row[field] = 113; expected = .missingContinuous
        case "utime": row[field] = 0; expected = .invalidFields("行情时间")
        default: row[field] = 0; expected = .invalidFields("最新价")
        }
        let data = try Fixtures.json(["qt": row])
        expectQuoteError(expected) {
            _ = try EastMoneyQuoteParser.parse(data, expectedCode: "114.lhm", fetchedAt: Fixtures.fetchedAt)
        }
    }

    @Test func missingMetricAndZeroVolumeAreIndependent() throws {
        var row = Fixtures.eastMoneyRow
        row.removeValue(forKey: "h")
        row["vol"] = 0
        let quote = try Fixtures.eastMoneyQuote(row)
        #expect(quote.formatted(.high) == "-")
        #expect(quote.formatted(.volume) == "0")
    }

    @Test func metricLabelsIdentifyBaseline() {
        #expect(Metric.percent.title(for: .eastmoney) == "涨跌幅（昨收）")
        #expect(Metric.percent.title(for: .sina) == "涨跌幅")
        #expect(Metric.change.title(for: .eastmoney) == "涨跌额（昨结）")
    }
}
