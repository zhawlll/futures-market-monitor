import Foundation

actor Probe {
    var calls: [String: [Date]] = [:]
    func record(_ id: String) { calls[id, default: []].append(Date()) }
}
