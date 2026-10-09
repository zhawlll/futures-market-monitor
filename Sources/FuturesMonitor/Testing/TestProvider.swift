import Foundation

struct TestProvider: QuoteProviding {
    let probe: Probe
    func quote(for instrument: Instrument) async throws -> Quote {
        await probe.record(instrument.id)
        if instrument.id == "si_qh" { throw QuoteError.empty }
        return Quote(symbol: instrument.eastMoneyMainCode?.components(separatedBy: ".").last?.uppercased() ?? "LC0", date: "2026-10-08", tickTime: "10:07:33", values: [.price: 123200], fetchedAt: Date(), source: instrument.quoteSource)
    }
}
