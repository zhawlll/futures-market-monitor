/// Clamp before arithmetic so even Int.min/Int.max text input can be stepped safely.
enum QueryInterval {
    static let minimum = 5
    static let maximum = 86400

    static func incremented(_ value: Int) -> Int {
        min(maximum, clamped(value) + 1)
    }
    static func decremented(_ value: Int) -> Int {
        max(minimum, clamped(value) - 1)
    }
    private static func clamped(_ value: Int) -> Int {
        min(maximum, max(minimum, value))
    }
}
