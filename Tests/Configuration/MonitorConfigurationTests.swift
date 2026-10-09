import Foundation
import Testing
@testable import FuturesMonitorCore

struct MonitorConfigurationTests {
    @Test func startsWithoutSelections() {
        let config = MonitorConfiguration()
        #expect(config.dataSource == nil)
        #expect(config.instruments.isEmpty)
        #expect(config.metrics.isEmpty)
        #expect(config.valid == false)
    }

    @Test(arguments: [(0, false), (4, false), (5, true), (86400, true), (86401, false)])
    func validatesInterval(value: Int, valid: Bool) {
        let config = MonitorConfiguration(instruments: [Fixtures.lc], metrics: [.price], interval: value, dataSource: .sina)
        #expect(config.valid == valid)
    }

    @Test func sanitizesDuplicatesAndInterval() {
        let config = MonitorConfiguration(instruments: [Fixtures.lc, Fixtures.si, Fixtures.lc],
                                          metrics: [.price, .price, .percent], interval: 0, dataSource: .sina).sanitized()
        #expect(config.interval == 5)
        #expect(config.instruments == [Fixtures.lc, Fixtures.si])
        #expect(config.metrics == [.price, .percent])
    }

    @Test func rejectsMixedSources() {
        let config = MonitorConfiguration(instruments: [Fixtures.lc], metrics: [.price], dataSource: .eastmoney)
        #expect(config.valid == false)
    }

    @Test func migratesLegacyConfigurationAndPersistsReferenceMetrics() throws {
        let catalog = try Fixtures.catalog("catalog")
        let eastmoney = try Fixtures.catalog("catalog-eastmoney")
        let ids = ["zzgz_qh", "by_qh", "lh_qh", "hz_qh", "lc_qh", "zly_qh"]
        let instruments = try ids.map { id in try #require(catalog.first { $0.id == id }) }
        let legacy = MonitorConfiguration(instruments: instruments, metrics: [.price, .percent], interval: 10, pinned: true)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        object.removeValue(forKey: "dataSource")
        let decoded = try JSONDecoder().decode(MonitorConfiguration.self, from: Fixtures.json(object))
        var migrated = decoded.migratingLegacy(to: eastmoney)
        #expect(migrated.valid)
        #expect(migrated.dataSource == .eastmoney)
        #expect(migrated.instruments.map(\.id) == ["em:220.ICM", "em:113.agm", "em:114.lhm", "em:115.CJM", "em:225.lcm", "em:114.pm"])
        #expect(migrated.metrics == legacy.metrics)
        #expect(migrated.interval == 10)
        #expect(migrated.pinned)
        migrated.metrics += [.marginRatio, .lotValue, .lotMargin, .feeDescription]
        #expect(try JSONDecoder().decode(MonitorConfiguration.self, from: JSONEncoder().encode(migrated)) == migrated)
        #expect(migrated.valid)
    }

    @Test func preservesUnmappableLegacyConfiguration() {
        let legacy = MonitorConfiguration(instruments: [Fixtures.lc], metrics: [.price])
        let migrated = legacy.migratingLegacy(to: [])
        #expect(migrated == legacy)
        #expect(migrated.valid == false)
    }
}

struct QueryIntervalTests {
    @Test(arguments: [(Int.min, 6, 5), (Int.max, 86400, 86399), (0, 6, 5), (5, 6, 5), (86400, 86400, 86399)])
    func clampsBeforeStepping(value: Int, incremented: Int, decremented: Int) {
        #expect(QueryInterval.incremented(value) == incremented)
        #expect(QueryInterval.decremented(value) == decremented)
    }
}
