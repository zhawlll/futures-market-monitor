import Foundation
import CoreFoundation

struct DemoQuoteService: QuoteProviding {
    let mixed: Bool
    func quote(for instrument: Instrument) async throws -> Quote {
        try await Task.sleep(nanoseconds: 200_000_000)
        if mixed && instrument.id == "si_qh" { throw QuoteError.empty }
        return Quote(symbol: "LC0", date: "2026-10-08", tickTime: "10:07:33",
                     values: [.price: 123200, .percent: 0.0368625, .change: 4380, .open: 118280,
                              .high: 125900, .low: 117920, .previousSettlement: 118820, .volume: 106295, .position: 410617], fetchedAt: Date())
    }
}
