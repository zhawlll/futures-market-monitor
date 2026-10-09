import Foundation

struct MonitorConfiguration: Codable, Equatable {
    var instruments: [Instrument] = []
    var metrics: [Metric] = []
    var interval: Int = 5
    var pinned = false
    var dataSource: DataSource? = nil
    var valid: Bool {
        dataSource != nil && !instruments.isEmpty && !metrics.isEmpty && interval >= 5 && interval <= 86400
            && instruments.allSatisfy { $0.dataSource == dataSource }
    }

    func migratingLegacy(to eastmoneyCatalog: [Instrument]) -> Self {
        guard dataSource == nil, !instruments.isEmpty else { return self }
        let mapped = instruments.compactMap { $0.counterpart(in: eastmoneyCatalog) }
        guard mapped.count == instruments.count else { return self }
        var copy = self
        copy.dataSource = .eastmoney
        copy.instruments = mapped
        return copy.sanitized()
    }

    func sanitized() -> Self {
        var copy = self
        var ids = Set<String>()
        copy.instruments = instruments.filter { ids.insert($0.id).inserted }
        var metricIDs = Set<Metric>()
        copy.metrics = metrics.filter { metricIDs.insert($0).inserted }
        copy.interval = max(5, min(86400, interval))
        return copy
    }
}
