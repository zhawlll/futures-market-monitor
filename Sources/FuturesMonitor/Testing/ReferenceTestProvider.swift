import Foundation

actor ReferenceTestProvider: BrokerReferenceProviding {
    let update: BrokerReferenceUpdate
    var calls = 0
    init(update: BrokerReferenceUpdate) { self.update = update }
    func fetch() async -> BrokerReferenceUpdate {
        calls += 1
        return update
    }
}
