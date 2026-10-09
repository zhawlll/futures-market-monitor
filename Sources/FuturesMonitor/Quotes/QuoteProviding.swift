import Foundation
import CoreFoundation

protocol QuoteProviding {
    func quote(for instrument: Instrument) async throws -> Quote
}

// Limit aggregate request starts in addition to each instrument's >= 5 second interval.
