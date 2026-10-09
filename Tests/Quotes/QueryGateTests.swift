import Foundation
import Testing
@testable import FuturesMonitorCore

struct QueryGateTests {
    @Test(.tags(.slow), .timeLimit(.minutes(1)))
    func repeatedInstrumentCannotBypassFiveSecondGate() async throws {
        let gate = QueryGate()
        let start = ContinuousClock.now
        try await gate.enter(for: Fixtures.lc.id)
        try await gate.enter(for: Fixtures.lc.id)
        #expect(start.duration(to: .now) >= .seconds(5))
    }

    @Test func cancellationInterruptsAGatedRequest() async throws {
        let gate = QueryGate()
        try await gate.enter(for: Fixtures.lc.id)
        let task = Task {
            try await gate.enter(for: Fixtures.lc.id)
        }
        task.cancel()
        do {
            try await task.value
            Issue.record("Canceled gate request must throw")
        } catch is CancellationError {
            return
        }
    }
}
