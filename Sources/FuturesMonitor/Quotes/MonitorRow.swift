import Foundation

struct MonitorRow: Identifiable {
    let instrument: Instrument
    var id: String { instrument.id }
    var quote: Quote?
    var status: RowStatus = .waiting
    var error: String?
    var lastAttempt: Date?
    var querying = false

    mutating func succeed(_ newQuote: Quote) {
        // Out-of-order source snapshots do not replace a newer successful snapshot.
        if quote == nil || quote?.source != newQuote.source || quote?.symbol != newQuote.symbol
            || newQuote.date + newQuote.tickTime >= quote!.date + quote!.tickTime {
            quote = newQuote
        }
        status = .success
        error = nil
        querying = false
    }
    mutating func fail(_ message: String) {
        status = quote == nil ? .unavailable : .failed
        error = message
        querying = false
    }
}
