import Foundation

struct Quote: Equatable {
    let symbol: String
    let date: String
    let tickTime: String
    let values: [Metric: Double]
    let fetchedAt: Date
    var source: String = "新浪财经"
    var previousClose: Double? = nil

    var displayTime: String { "\(date.dropFirst(5)) \(tickTime)" }
    func formatted(_ metric: Metric) -> String {
        guard let value = values[metric], value.isFinite else { return "-" }
        let minimumDigits = metric == .percent ? 2 : 0
        let maximumDigits = metric == .percent ? 2 : (metric == .volume || metric == .position ? 0 : 3)
        let displayedValue = metric == .percent ? value * 100 : value
        let text = displayedValue.formatted(
            .number.locale(Locale(identifier: "en_US"))
                .precision(.fractionLength(minimumDigits...maximumDigits))
        )
        let sign = (metric == .percent || metric == .change) && value > 0 ? "+" : ""
        return sign + text + (metric == .percent ? "%" : "")
    }
}
