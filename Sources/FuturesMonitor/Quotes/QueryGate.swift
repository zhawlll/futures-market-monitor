import Foundation
import CoreFoundation

actor QueryGate {
    private var nextSlot = Date.distantPast
    private var nextForInstrument: [String: Date] = [:]
    func enter(for instrumentID: String) async throws {
        while true {
            try Task.checkCancellation()
            let now = Date()
            let slot = max(nextSlot, nextForInstrument[instrumentID] ?? .distantPast)
            let delay = slot.timeIntervalSince(now)
            if delay <= 0 {
                nextSlot = now.addingTimeInterval(0.5)
                nextForInstrument[instrumentID] = now.addingTimeInterval(5)
                return
            }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
