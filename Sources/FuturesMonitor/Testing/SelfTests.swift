import Foundation

// Bundle smoke check. Unit and integration regressions live in Tests/ and run
// independently through Swift Testing using scripts/test.sh.
enum SelfTests {
    @MainActor static func run() async -> Bool {
        var checks = 0
        var failures = 0
        func check(_ condition: Bool, _ name: String) {
            checks += 1
            if condition { print("PASS \(name)") }
            else { failures += 1; print("FAIL \(name)") }
        }
        func require<T>(_ value: T?, _ name: String) throws -> T {
            guard let value else {
                throw NSError(domain: "SelfTest", code: 1, userInfo: [NSLocalizedDescriptionKey: name])
            }
            return value
        }
        do {
            let catalogURL = try require(Bundle.main.url(forResource: "catalog", withExtension: "json"), "应用包缺少新浪目录")
            let catalog = try JSONDecoder().decode([Instrument].self, from: Data(contentsOf: catalogURL))
            check(catalog.count >= 70 && Set(catalog.map(\.id)).count == catalog.count, "应用包新浪目录完整且无重复")
            let emURL = try require(Bundle.main.url(forResource: "catalog-eastmoney", withExtension: "json"), "应用包缺少东方财富目录")
            let emCatalog = try JSONDecoder().decode([Instrument].self, from: Data(contentsOf: emURL))
            check(emCatalog.count == 90 && Set(emCatalog.map(\.id)).count == 90, "应用包东方财富目录完整且无重复")
            let resources = try require(Bundle.main.resourceURL, "应用包缺少资源目录")
            let mapping = try CatalogParser.parse(Data(contentsOf: resources.appendingPathComponent("test-fixtures/catalog-sina.js")))
            check(mapping == catalog, "应用包编码品种映射与目录一致")
            let lc = try require(catalog.first { $0.id == "lc_qh" }, "目录缺少碳酸锂")
            let si = try require(catalog.first { $0.id == "si_qh" }, "目录缺少工业硅")
            let emLC = try require(lc.counterpart(in: emCatalog), "东方财富目录缺少碳酸锂对应品种")
            check(emLC.eastMoneyMainCode == "225.lcm", "应用包支持跨来源品种对应")
            let suite = "com.futuresmonitor.app.smoke.\(UUID().uuidString)"
            let defaults = try require(UserDefaults(suiteName: suite), "无法创建独立测试配置域")
            defer { defaults.removePersistentDomain(forName: suite) }
            let referenceProvider = ReferenceTestProvider(update: BrokerReferenceUpdate())
            let store = MonitorStore(defaults: defaults, provider: TestProvider(probe: Probe()), referenceProvider: referenceProvider)
            defer { store.stopWorkers() }
            let configuration = MonitorConfiguration(instruments: [lc, si], metrics: [.price], dataSource: .sina)
            store.save(configuration)
            try await waitUntil("模拟行情未完成") {
                store.rows.count == 2 && store.rows[0].status == .success && store.rows[1].status == .unavailable
            }
            check(store.rows[0].quote?.values[.price] == 123200 && store.rows[1].quote == nil, "应用包模拟查询按行更新")
            let restored = MonitorStore(defaults: defaults, provider: TestProvider(probe: Probe()), referenceProvider: referenceProvider)
            check(restored.configuration == configuration, "应用包配置可持久化和恢复")
            let cached = store.rows[0].quote
            let workers = store.togglePause()
            for worker in workers { await worker.value }
            check(store.paused && store.rows[0].quote == cached && store.rows.allSatisfy { !$0.querying }, "应用包暂停后任务结束且缓存保留")
            check(await referenceProvider.calls == 0, "普通行情指标不请求公司资料")
            print("\n\(checks) smoke checks, \(failures) failures")
            return failures == 0
        } catch {
            print("FAIL \(error.localizedDescription)")
            return false
        }
    }

    @MainActor private static func waitUntil(_ name: String, condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition() {
            guard ContinuousClock.now < deadline else {
                throw NSError(domain: "SelfTest", code: 2, userInfo: [NSLocalizedDescriptionKey: name])
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    static func liveCheck() async -> Bool {
        let service = FuturesQuoteService()
        do {
            let referenceUpdate = await BrokerReferenceService().fetch()
            var references = BrokerSnapshot()
            references.apply(referenceUpdate)
            print("东方财富公司资料：乘数\(references.contracts.count)、保证金\(references.margins.count)、手续费\(references.fees.count)，错误：\(references.errors)")
            guard referenceUpdate.errors.isEmpty else { return false }
            var successes = Set<String>()
            for source in DataSource.allCases {
                let catalog = try await service.catalog(source: source)
                print("\(source.name) 在线支持品种：\(catalog.count)")
                let names = source == .eastmoney ? ["生猪", "碳酸锂", "白银", "中证500", "红枣", "棕榈油"] : ["生猪", "碳酸锂"]
                for name in names {
                guard let instrument = catalog.first(where: { $0.canonicalName == name.lowercased() }) else { throw QuoteError.empty }
                do {
                    let quote = try await service.quote(for: instrument)
                    let closeText = quote.previousClose.map { String($0) } ?? "-"
                    print("\(instrument.name) \(quote.symbol) \(quote.date) \(quote.tickTime) 最新价=\(quote.formatted(.price)) \(Metric.percent.title(for: source))=\(quote.formatted(.percent)) 昨收=\(closeText) 昨结算=\(quote.formatted(.previousSettlement)) 持仓量=\(quote.formatted(.position)) 来源=\(quote.source)")
                    var row = MonitorRow(instrument: instrument)
                    row.succeed(quote)
                    print("  1手价格=\(references.formatted(.lotValue, row: row))元 公司保证金比例=\(references.formatted(.marginRatio, row: row)) 一手保证金=\(references.formatted(.lotMargin, row: row))元 手续费说明=\(references.formatted(.feeDescription, row: row))")
                    guard [Metric.lotValue, .lotMargin, .marginRatio, .feeDescription].allSatisfy({ references.formatted($0, row: row) != "-" }) else { throw QuoteError.empty }
                    successes.insert(source.rawValue + ":" + name)
                } catch { print("\(name) 查询失败：\(error.localizedDescription)") }
            }
            }
            return successes.count == 8
        } catch { print("在线验证失败：\(error.localizedDescription)"); return false }
    }
}
