import Foundation
import Testing
@testable import FuturesMonitorCore

struct BrokerSnapshotTests {
    private func snapshot() -> BrokerSnapshot {
        var result = BrokerSnapshot()
        result.apply(Fixtures.referenceUpdate)
        return result
    }
    private func row() throws -> MonitorRow {
        var row = MonitorRow(instrument: Fixtures.emLH)
        row.succeed(try Fixtures.eastMoneyQuote())
        return row
    }

    @Test func noQuoteMeansReferenceMetricsRemainPlaceholders() {
        var row = MonitorRow(instrument: Fixtures.emLH)
        row.fail("offline")
        for metric in [Metric.lotValue, .lotMargin, .marginRatio, .feeDescription] {
            #expect(snapshot().formatted(metric, row: row) == "-")
        }
    }

    @Test func calculatesValueAndMarginFromTypedInputs() throws {
        let references = snapshot()
        var row = try row()
        #expect(references.formatted(.lotValue, row: row) == "166,560")
        #expect(references.formatted(.lotMargin, row: row) == "33,312")
        #expect(references.formatted(.marginRatio, row: row) == "20%")
        #expect(references.formatted(.feeDescription, row: row) != "-")
        row.fail("timeout")
        #expect(references.formatted(.lotValue, row: row) == "166,560")
        #expect(references.formatted(.lotMargin, row: row) == "33,312")
    }

    @Test(arguments: ["contract", "margin"])
    func missingInputsPreventAmountCalculation(missing: String) throws {
        var references = snapshot()
        if missing == "contract" { references.contracts.removeValue(forKey: "DCE:LH") }
        else { references.margins.removeValue(forKey: "DCE:LH") }
        #expect(references.formatted(.lotMargin, row: try row()) == "-")
    }

    @Test(arguments: [Double.nan, Double.infinity, -0.1, 0, 1.1, 0.125, 1])
    func validatesMarginRatio(ratio: Double) throws {
        var references = snapshot()
        references.margins["DCE:LH"] = MarginTerms(ratio: ratio, text: "人工比例", mainContract: "LH9901", exceptions: "", fetchedAt: Fixtures.fetchedAt)
        let expected = ratio == 0.125 ? "20,820" : ratio == 1 ? "166,560" : "-"
        #expect(references.formatted(.lotMargin, row: try row()) == expected)
    }

    @Test func partialFailureRetainsCacheAndReportsAffectedInputs() throws {
        var references = snapshot()
        let row = try row()
        references.apply(BrokerReferenceUpdate(contracts: Fixtures.referenceUpdate.contracts, errors: [.margins: "timeout", .fees: "offline"]))
        #expect(references.formatted(.marginRatio, row: row) == "20%")
        #expect(references.fees == Fixtures.referenceUpdate.fees)
        #expect(references.error(for: .marginRatio) != nil)
        #expect(references.error(for: .lotValue) == nil)
        #expect(references.formatted(.lotMargin, row: row) == "33,312")
        #expect(references.error(for: .lotMargin)?.contains("保证金比例") == true)
        references.apply(BrokerReferenceUpdate(margins: Fixtures.referenceUpdate.margins, errors: [.contracts: "timeout"]))
        #expect(references.formatted(.lotMargin, row: row) == "33,312")
        #expect(references.error(for: .lotMargin)?.contains("合约单位") == true)
        references.apply(Fixtures.referenceUpdate)
        #expect(references.errors.isEmpty)
        #expect(references.details(.feeDescription, row: row).contains("收费上限"))
    }

    @Test func unknownSymbolDoesNotUseOtherContracts() {
        var row = MonitorRow(instrument: Fixtures.emLH)
        row.succeed(Quote(symbol: "UNKNOWNM", date: "2026-10-08", tickTime: "11:30:00", values: [.price: 100], fetchedAt: Fixtures.fetchedAt, source: "东方财富"))
        #expect(snapshot().formatted(.lotValue, row: row) == "-")
    }

    @Test func formatsAmountsAndRejectsNonfiniteValues() {
        #expect(BrokerSnapshot.number(1234.567, decimals: 2) == "1,234.57")
        #expect(BrokerSnapshot.number(1234, decimals: 2) == "1,234")
        #expect(BrokerSnapshot.number(.nan, decimals: 2) == "-")
    }
}
