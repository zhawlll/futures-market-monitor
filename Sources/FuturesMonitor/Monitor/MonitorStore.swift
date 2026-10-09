import Foundation
import Observation

@MainActor
@Observable
final class MonitorStore {
    var configuration: MonitorConfiguration
    private(set) var instrumentColumnWidth: CGFloat
    var rows: [MonitorRow] = []
    private(set) var catalogs: [DataSource: [Instrument]] = [:]
    private(set) var loadingSources: Set<DataSource> = []
    private(set) var catalogNotes: [DataSource: String] = [:]
    var paused = false
    private(set) var references = BrokerSnapshot()
    let isDemo: Bool
    private let provider: QuoteProviding
    private let networkService: FuturesQuoteService
    private let referenceProvider: BrokerReferenceProviding
    private let defaults: UserDefaults
    private var workers: [String: Task<Void, Never>] = [:]
    private var generation = UUID()
    private var referenceWorker: Task<Void, Never>?
    private static let key = "monitor.configuration.v1"
    private static let columnWidthKey = "monitor.instrument-column-width.v1"

    init(defaults: UserDefaults = .standard, provider: QuoteProviding? = nil, referenceProvider: BrokerReferenceProviding = BrokerReferenceService(), demo: Bool = false) {
        self.defaults = defaults
        self.isDemo = demo
        instrumentColumnWidth = MonitorLayout.clampInstrumentColumnWidth(
            demo ? MonitorLayout.fixedColumnWidth : CGFloat((defaults.object(forKey: Self.columnWidthKey) as? NSNumber)?.doubleValue ?? Double(MonitorLayout.fixedColumnWidth)))
        self.referenceProvider = referenceProvider
        let service = FuturesQuoteService()
        self.networkService = service
        self.provider = provider ?? service
        if !demo, let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(MonitorConfiguration.self, from: data) {
            configuration = saved.sanitized()
        } else { configuration = MonitorConfiguration() }
        for (source, name) in [(DataSource.sina, "catalog"), (.eastmoney, "catalog-eastmoney")] {
            let url = Bundle.main.url(forResource: name, withExtension: "json")
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/\(name).json")
            if let data = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([Instrument].self, from: data) {
                catalogs[source] = list
            }
        }
        configuration = configuration.migratingLegacy(to: catalog(for: .eastmoney))
        if demo {
            configuration = MonitorConfiguration(instruments: ["lc_qh", "si_qh", "ps_qh"].compactMap { id in catalog(for: .sina).first { $0.id == id } }, metrics: [.price, .percent, .position], interval: 5, dataSource: .sina)
        }
        rows = configuration.instruments.map { MonitorRow(instrument: $0) }
    }

    func catalog(for source: DataSource?) -> [Instrument] { source.flatMap { catalogs[$0] } ?? [] }
    func loadCatalog(_ requestedSource: DataSource? = nil) async {
        guard let source = requestedSource ?? configuration.dataSource,
              !isDemo, !loadingSources.contains(source) else { return }
        loadingSources.insert(source)
        defer { loadingSources.remove(source) }
        do {
            catalogs[source] = try await networkService.catalog(source: source)
            catalogNotes[source] = nil
        } catch {
            catalogNotes[source] = catalog(for: source).isEmpty ? "品种列表加载失败，请重试" : "在线列表暂不可用，正在使用内置品种列表"
        }
    }

    @discardableResult
    func save(_ draft: MonitorConfiguration) -> [Task<Void, Never>] {
        guard draft.valid else { return [] }
        let stopped = stopWorkers()
        var next = draft.sanitized()
        // Pinning is edited directly in the monitor, outside the settings draft.
        next.pinned = configuration.pinned
        let existing = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        rows = next.instruments.map { instrument in
            // Metrics/interval edits preserve in-session successful quotes for unchanged instruments.
            if configuration.dataSource == next.dataSource,
               let old = existing[instrument.id], old.instrument == instrument { return old }
            return MonitorRow(instrument: instrument)
        }
        configuration = next
        paused = false
        persist()
        startWorkers()
        return stopped
    }
    func persist() {
        guard !isDemo else { return }
        defaults.set(try? JSONEncoder().encode(configuration), forKey: Self.key)
    }
    func setPinned(_ value: Bool) { configuration.pinned = value; persist() }
    func setInstrumentColumnWidth(_ width: CGFloat, persist: Bool = true) {
        instrumentColumnWidth = MonitorLayout.clampInstrumentColumnWidth(width)
        if persist && !isDemo { defaults.set(Double(instrumentColumnWidth), forKey: Self.columnWidthKey) }
    }
    @discardableResult
    func togglePause() -> [Task<Void, Never>] {
        paused.toggle()
        if paused { return stopWorkers() }
        startWorkers()
        return []
    }
    func startWorkers() {
        guard !isDemo, configuration.valid, !paused, workers.isEmpty else { return }
        let token = generation
        let delay = UInt64(max(5, configuration.interval)) * 1_000_000_000
        if configuration.metrics.contains(where: { $0.referencePart != nil }) {
            referenceWorker = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled && self.generation == token {
                    let update = await self.referenceProvider.fetch()
                    guard !Task.isCancelled, self.generation == token else { return }
                    self.references.apply(update)
                    let seconds: UInt64 = update.errors.isEmpty ? 1800 : 60
                    do { try await Task.sleep(nanoseconds: seconds * 1_000_000_000) } catch { return }
                }
            }
        }
        for instrument in configuration.instruments {
            workers[instrument.id] = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled && self.generation == token {
                    self.update(instrument.id) { $0.querying = true; $0.lastAttempt = Date() }
                    do {
                        let quote = try await self.provider.quote(for: instrument)
                        guard !Task.isCancelled, self.generation == token else { return }
                        self.update(instrument.id) { $0.succeed(quote) }
                    } catch {
                        guard !Task.isCancelled, self.generation == token else { return }
                        self.update(instrument.id) { $0.fail(error.localizedDescription) }
                    }
                    do { try await Task.sleep(nanoseconds: delay) } catch { return }
                }
            }
        }
    }
    // Return canceled tasks so callers can await completion when they need to
    // observe an in-flight provider returning after cancellation.
    @discardableResult
    func stopWorkers() -> [Task<Void, Never>] {
        let stopped = Array(workers.values) + (referenceWorker.map { [$0] } ?? [])
        generation = UUID()
        referenceWorker?.cancel()
        referenceWorker = nil
        workers.values.forEach { $0.cancel() }
        workers.removeAll()
        for index in rows.indices { rows[index].querying = false }
        return stopped
    }
    private func update(_ id: String, _ mutate: (inout MonitorRow) -> Void) {
        if let index = rows.firstIndex(where: { $0.id == id }) { mutate(&rows[index]) }
    }
    var summary: String {
        if paused { return "已暂停 · 数据保持不变" }
        let good = rows.filter { $0.status == .success }.count
        let failed = rows.filter { $0.status == .failed }.count
        let empty = rows.filter { $0.status == .unavailable }.count
        let waiting = rows.filter { $0.status == .waiting }.count
        var parts = ["\(good) 个正常"]
        if failed > 0 { parts.append("\(failed) 个更新失败") }
        if empty > 0 { parts.append("\(empty) 个未获取") }
        if waiting > 0 { parts.append("\(waiting) 个查询中") }
        return parts.joined(separator: " · ")
    }
    func installDemoRows() {
        stopWorkers()
        guard !rows.isEmpty else { return }
        let quote = Quote(symbol: "LC0", date: "2026-10-08", tickTime: "10:07:33",
                          values: [.price: 123200, .percent: 0.0368625, .position: 410617], fetchedAt: Date())
        rows[0].succeed(quote)
        if rows.count > 1 {
            rows[1].succeed(Quote(symbol: "SI0", date: "2026-10-08", tickTime: "10:07:28",
                values: [.price: 8495, .percent: -0.0064, .position: 210360], fetchedAt: Date()))
            rows[1].fail("演示：网络连接超时，保留上次成功数据")
        }
        if rows.count > 2 { rows[2].fail("演示：尚未获得有效行情") }
    }
}
