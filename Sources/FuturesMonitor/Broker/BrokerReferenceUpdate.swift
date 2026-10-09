import Foundation

struct BrokerReferenceUpdate {
    var contracts: [String: ContractSpec]?
    var margins: [String: MarginTerms]?
    var fees: [String: FeeTerms]?
    var errors: [ReferencePart: String] = [:]
}
