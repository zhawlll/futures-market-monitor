import Foundation
import Testing
@testable import FuturesMonitorCore

extension Tag {
    @Tag static var slow: Self
    @Tag static var networking: Self
}

enum TestWaitError: Error { case timeout(String) }

@MainActor
func waitUntil(_ description: String, timeout: Duration = .seconds(3),
               condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while await condition() == false {
        guard ContinuousClock.now < deadline else { throw TestWaitError.timeout(description) }
        try await Task.sleep(for: .milliseconds(10))
    }
}

func expectQuoteError(_ expected: QuoteError, sourceLocation: SourceLocation = #_sourceLocation,
                      performing body: () throws -> Void) {
    do {
        try body()
        Issue.record("Expected \(expected)", sourceLocation: sourceLocation)
    } catch {
        #expect((error as? QuoteError) == expected, sourceLocation: sourceLocation)
    }
}

final class DefaultsFixture {
    let suite = "com.futuresmonitor.app.tests.\(UUID().uuidString)"
    let defaults: UserDefaults
    init() throws { defaults = try #require(UserDefaults(suiteName: suite)) }
    deinit { defaults.removePersistentDomain(forName: suite) }
}

// Cancellation deliberately does not resume pending requests. Tests control when
// a canceled provider returns, then await the retired MonitorStore tasks.
actor ControlledQuoteProvider: QuoteProviding {
    struct Request: Equatable {
        let id: Int
        let instrument: Instrument
    }
    private(set) var requests: [Request] = []
    private var pending: [Int: CheckedContinuation<Quote, Error>] = [:]
    func quote(for instrument: Instrument) async throws -> Quote {
        try await withCheckedThrowingContinuation { continuation in
            let request = Request(id: requests.count, instrument: instrument)
            requests.append(request)
            pending[request.id] = continuation
        }
    }
    func complete(_ request: Request, with result: Result<Quote, Error>) {
        pending.removeValue(forKey: request.id)?.resume(with: result)
    }
    func finishAll() {
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations { continuation.resume(throwing: CancellationError()) }
    }
}

actor StubReferenceProvider: BrokerReferenceProviding {
    private(set) var calls = 0
    let update: BrokerReferenceUpdate
    init(update: BrokerReferenceUpdate = Fixtures.referenceUpdate) { self.update = update }
    func fetch() async -> BrokerReferenceUpdate { calls += 1; return update }
}

@MainActor
final class StoreFixture {
    let persistence: DefaultsFixture
    let quotes = ControlledQuoteProvider()
    let references = StubReferenceProvider()
    let store: MonitorStore
    private var retiredWorkers: [Task<Void, Never>] = []
    init() throws {
        persistence = try DefaultsFixture()
        store = MonitorStore(defaults: persistence.defaults, provider: quotes, referenceProvider: references)
    }
    func request(_ index: Int) async throws -> ControlledQuoteProvider.Request {
        try await waitUntil("quote request \(index)") { await self.quotes.requests.count > index }
        return try #require(await quotes.requests.dropFirst(index).first)
    }
    @discardableResult
    func save(_ configuration: MonitorConfiguration) -> [Task<Void, Never>] {
        let retired = store.save(configuration)
        retiredWorkers += retired
        return retired
    }
    func close() async {
        let workers = store.stopWorkers() + retiredWorkers
        await quotes.finishAll()
        for worker in workers { await worker.value }
    }
}

actor PollingQuoteProvider: QuoteProviding {
    private(set) var starts: [ContinuousClock.Instant] = []
    func quote(for instrument: Instrument) async throws -> Quote {
        starts.append(ContinuousClock.now)
        return Fixtures.quote(for: instrument)
    }
}

@MainActor
func withStore(_ body: (StoreFixture) async throws -> Void) async throws {
    let fixture = try StoreFixture()
    do { try await body(fixture) }
    catch { await fixture.close(); throw error }
    await fixture.close()
}
