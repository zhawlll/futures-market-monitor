import Foundation
import Testing
@testable import FuturesMonitorCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MonitorStoreTests {
    private func configuration(_ instrument: Instrument, metrics: [Metric] = [.price]) -> MonitorConfiguration {
        MonitorConfiguration(instruments: [instrument], metrics: metrics, dataSource: instrument.dataSource)
    }

    @Test(.tags(.networking), arguments: [false, true])
    func retiredSameInstrumentRequestCannotOverwriteNewResult(oldFails: Bool) async throws {
        try await withStore { fixture in
            fixture.save(configuration(Fixtures.lc))
            let oldRequest = try await fixture.request(0)
            let retired = fixture.save(configuration(Fixtures.lc, metrics: [.position]))
            try #require(retired.isEmpty == false)
            let newRequest = try await fixture.request(1)
            let newQuote = Fixtures.quote(for: Fixtures.lc, price: 200, time: "11:00:00")
            await fixture.quotes.complete(newRequest, with: .success(newQuote))
            try await waitUntil("new quote applied") { fixture.store.rows.first?.quote == newQuote }

            // Later source time would overwrite the new quote if the retired task
            // were allowed to apply its result. The fake deliberately ignores cancellation.
            let result: Result<Quote, Error> = oldFails ? .failure(QuoteError.empty)
                : .success(Fixtures.quote(for: Fixtures.lc, price: 999, time: "12:00:00"))
            await fixture.quotes.complete(oldRequest, with: result)
            for worker in retired { await worker.value }
            #expect(fixture.store.rows.first?.quote == newQuote)
            #expect(fixture.store.rows.first?.status == .success)
            #expect(fixture.store.rows.first?.error == nil)
        }
    }

    @Test(.tags(.networking))
    func sourceSwitchClearsCacheAndRejectsLateOldSourceResult() async throws {
        try await withStore { fixture in
            fixture.save(configuration(Fixtures.lc))
            let oldRequest = try await fixture.request(0)
            // Seed an existing successful cache while leaving a request pending.
            let cached = Fixtures.quote(for: Fixtures.lc)
            fixture.store.rows[0].succeed(cached)
            let retired = fixture.save(configuration(Fixtures.emLC))
            #expect(fixture.store.rows.first?.quote == nil)
            #expect(fixture.store.rows.first?.status == .waiting)
            let newRequest = try await fixture.request(1)
            let newQuote = Fixtures.quote(for: Fixtures.emLC, price: 200)
            await fixture.quotes.complete(newRequest, with: .success(newQuote))
            try await waitUntil("new source quote applied") { fixture.store.rows.first?.quote == newQuote }
            await fixture.quotes.complete(oldRequest, with: .success(cached))
            for worker in retired { await worker.value }
            #expect(fixture.store.rows.first?.instrument == Fixtures.emLC)
            #expect(fixture.store.rows.first?.quote == newQuote)
            #expect(fixture.store.rows.first?.quote?.source == "东方财富")
        }
    }

    @Test(.tags(.networking))
    func instrumentSwitchDoesNotApplyOldQuoteToNewRow() async throws {
        try await withStore { fixture in
            fixture.save(configuration(Fixtures.lc))
            let oldRequest = try await fixture.request(0)
            let retired = fixture.save(configuration(Fixtures.si))
            let newRequest = try await fixture.request(1)
            await fixture.quotes.complete(newRequest, with: .failure(QuoteError.empty))
            try await waitUntil("new instrument failure applied") { fixture.store.rows.first?.status == .unavailable }
            await fixture.quotes.complete(oldRequest, with: .success(Fixtures.quote(for: Fixtures.lc)))
            for worker in retired { await worker.value }
            #expect(fixture.store.rows.count == 1)
            #expect(fixture.store.rows.first?.id == Fixtures.si.id)
            #expect(fixture.store.rows.first?.quote == nil)
        }
    }

    @Test(.tags(.networking))
    func rowsHandleSuccessAndFirstFailureIndependently() async throws {
        try await withStore { fixture in
            fixture.save(MonitorConfiguration(instruments: [Fixtures.lc, Fixtures.si], metrics: [.price], dataSource: .sina))
            _ = try await fixture.request(1)
            let requests = await fixture.quotes.requests
            let lcRequest = try #require(requests.first { $0.instrument == Fixtures.lc })
            let siRequest = try #require(requests.first { $0.instrument == Fixtures.si })
            await fixture.quotes.complete(lcRequest, with: .success(Fixtures.quote(for: Fixtures.lc)))
            await fixture.quotes.complete(siRequest, with: .failure(QuoteError.empty))
            try await waitUntil("both row results applied") {
                fixture.store.rows.allSatisfy { $0.querying == false }
            }
            #expect(fixture.store.rows[0].status == .success)
            #expect(fixture.store.rows[1].status == .unavailable)
        }
    }

    @Test(.tags(.networking))
    func pauseRetainsCacheAfterAnInflightResultReturns() async throws {
        try await withStore { fixture in
            fixture.save(configuration(Fixtures.lc))
            let request = try await fixture.request(0)
            let cached = Fixtures.quote(for: Fixtures.lc)
            fixture.store.rows[0].succeed(cached)
            let retired = fixture.store.togglePause()
            await fixture.quotes.complete(request, with: .success(Fixtures.quote(for: Fixtures.lc, price: 999, time: "12:00:00")))
            for worker in retired { await worker.value }
            #expect(fixture.store.paused)
            #expect(fixture.store.rows.first?.quote == cached)
            #expect(fixture.store.rows.first?.querying == false)
            #expect(await fixture.quotes.requests.count == 1)
        }
    }

    @Test(.tags(.networking))
    func editingMetricsPreservesCache() async throws {
        try await withStore { fixture in
            fixture.save(configuration(Fixtures.lc))
            let request = try await fixture.request(0)
            let quote = Fixtures.quote(for: Fixtures.lc)
            await fixture.quotes.complete(request, with: .success(quote))
            try await waitUntil("initial quote applied") { fixture.store.rows.first?.quote == quote }
            fixture.save(configuration(Fixtures.lc, metrics: [.position]))
            #expect(fixture.store.rows.first?.quote == quote)
        }
    }

    @Test(.tags(.networking), arguments: [false, true])
    func onlyReferenceMetricsStartReferenceRequests(needsReference: Bool) async throws {
        try await withStore { fixture in
            fixture.save(configuration(Fixtures.emLC, metrics: needsReference ? [.lotMargin] : [.price]))
            let request = try await fixture.request(0)
            await fixture.quotes.complete(request, with: .success(Fixtures.quote(for: Fixtures.emLC)))
            try await waitUntil("quote and selected reference metrics applied") {
                fixture.store.rows.first?.status == .success &&
                    (needsReference == false || fixture.store.references.formatted(.lotMargin, row: fixture.store.rows[0]) == "41,888")
            }
            // Await workers to ensure a wrongly-started reference task cannot
            // escape a zero-call assertion by being scheduled after the check.
            let workers = fixture.store.stopWorkers()
            for worker in workers { await worker.value }
            #expect(await fixture.references.calls == (needsReference ? 1 : 0))
        }
    }

    @Test func savingStaleDraftPreservesLatestPinAndPersistsIt() async throws {
        try await withStore { fixture in
            fixture.save(configuration(Fixtures.lc))
            var draft = fixture.store.configuration
            fixture.store.setPinned(true)
            draft.interval = 10
            fixture.save(draft)
            #expect(fixture.store.configuration.pinned)
            #expect(fixture.store.configuration.interval == 10)
            let restored = MonitorStore(defaults: fixture.persistence.defaults, provider: fixture.quotes, referenceProvider: fixture.references)
            #expect(restored.configuration.pinned)
            draft = fixture.store.configuration
            fixture.store.setPinned(false)
            fixture.save(draft)
            #expect(fixture.store.configuration.pinned == false)
        }
    }

    @Test(.tags(.slow, .networking), .timeLimit(.minutes(1)))
    func pollingWaitsAtLeastFiveSecondsAndStopsOnPause() async throws {
        let persistence = try DefaultsFixture()
        let provider = PollingQuoteProvider()
        let store = MonitorStore(defaults: persistence.defaults, provider: provider, referenceProvider: StubReferenceProvider())
        defer { store.stopWorkers() }
        store.save(configuration(Fixtures.lc))
        try await waitUntil("second polling request", timeout: .seconds(12)) { await provider.starts.count >= 2 }
        let starts = await provider.starts
        try #require(starts.count >= 2)
        #expect(starts[0].duration(to: starts[1]) >= .seconds(5))
        let workers = store.togglePause()
        for worker in workers { await worker.value }
        #expect(store.paused)
        #expect(store.rows.first?.querying == false)
    }
}
