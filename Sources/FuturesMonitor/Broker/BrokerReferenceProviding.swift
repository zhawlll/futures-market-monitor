import Foundation

protocol BrokerReferenceProviding {
    func fetch() async -> BrokerReferenceUpdate
}
