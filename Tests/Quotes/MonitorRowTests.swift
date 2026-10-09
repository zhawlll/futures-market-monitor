import Foundation
import Testing
@testable import FuturesMonitorCore

struct MonitorRowTests {
    @Test func firstFailureHasNoCachedQuote() {
        var row = MonitorRow(instrument: Fixtures.lc)
        row.fail("offline")
        #expect(row.quote == nil)
        #expect(row.status == .unavailable)
    }

    @Test func failureRetainsQuoteAndRecoveryClearsError() {
        var row = MonitorRow(instrument: Fixtures.lc)
        let quote = Fixtures.quote(for: Fixtures.lc)
        row.succeed(quote)
        row.fail("timeout")
        #expect(row.quote == quote)
        #expect(row.status == .failed)
        row.succeed(quote)
        #expect(row.status == .success)
        #expect(row.error == nil)
    }

    @Test func olderSourceTimestampCannotReplaceNewerQuote() {
        var row = MonitorRow(instrument: Fixtures.lc)
        let quote = Fixtures.quote(for: Fixtures.lc)
        row.succeed(quote)
        row.succeed(Quote(symbol: "LC0", date: "2026-09-30", tickTime: "15:00:00", values: [.price: 1], fetchedAt: Fixtures.fetchedAt))
        #expect(row.quote == quote)
    }

    @Test func sourceChangeReplacesOldQuoteEvenWithEarlierTimestamp() throws {
        var row = MonitorRow(instrument: Fixtures.lh)
        row.succeed(Fixtures.quote(for: Fixtures.lh, time: "11:45:00"))
        let quote = try Fixtures.eastMoneyQuote()
        row.succeed(quote)
        row.fail("timeout")
        #expect(row.quote == quote)
        #expect(row.status == .failed)
    }
}

struct QuoteFormattingTests {
    @Test func preservesGroupingPrecisionSignsAndPlaceholders() {
        let quote = Quote(symbol: "LC0", date: "2026-10-08", tickTime: "10:00:00", values: [.price: 1234.5678, .percent: 0.01, .change: 0, .volume: 12345, .high: .infinity], fetchedAt: Fixtures.fetchedAt)
        #expect(quote.formatted(.price) == "1,234.568")
        #expect(quote.formatted(.percent) == "+1.00%")
        #expect(quote.formatted(.change) == "0")
        #expect(quote.formatted(.volume) == "12,345")
        #expect(quote.formatted(.high) == "-")
    }
}

struct MonitorLayoutTests {
    @Test func fitsRowsByCompressingPaddingWithinBounds() {
        #expect(MonitorLayout.rowPadding(availableHeight: 600, rowCount: 6) == 13)
        let compressed = MonitorLayout.rowPadding(availableHeight: 270, rowCount: 6)
        #expect(compressed > 3)
        #expect(compressed < 13)
        #expect(MonitorLayout.headerHeight + 6 * (MonitorLayout.rowContentHeight + 1 + 2 * compressed) <= 270.001)
        #expect(MonitorLayout.rowPadding(availableHeight: 200, rowCount: 6) == 3)
        #expect(MonitorLayout.rowPadding(availableHeight: 0, rowCount: 0) == 13)
    }
}
