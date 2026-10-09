import Foundation

actor BrokerReferenceService: BrokerReferenceProviding {
    private let session: URLSession
    private var inFlight: Task<BrokerReferenceUpdate, Never>?
    private var cached: BrokerReferenceUpdate?
    private var fetchedAt = Date.distantPast
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }
    func fetch() async -> BrokerReferenceUpdate {
        if let inFlight { return await inFlight.value }
        if let cached, Date().timeIntervalSince(fetchedAt) < 60 { return cached }
        let session = session
        let task = Task { await Self.download(session: session) }
        inFlight = task
        let result = await task.value
        cached = result
        fetchedAt = Date()
        inFlight = nil
        return result
    }
    private enum Result {
        case contracts([String: ContractSpec]), margins([String: MarginTerms]), fees([String: FeeTerms])
        case failure(ReferencePart, String)
    }
    private static func download(session: URLSession) async -> BrokerReferenceUpdate {
        await withTaskGroup(of: Result.self) { group in
            for part in ReferencePart.allCases {
                group.addTask {
                    do {
                        var request = URLRequest(url: part.url)
                        request.setValue("Mozilla/5.0 FuturesMonitor/1.2", forHTTPHeaderField: "User-Agent")
                        request.setValue("https://portal.eastmoneyfutures.com/", forHTTPHeaderField: "Referer")
                        let (data, response) = try await session.data(for: request)
                        guard let http = response as? HTTPURLResponse else { throw QuoteError.invalidResponse }
                        guard (200..<300).contains(http.statusCode) else { throw QuoteError.http(http.statusCode) }
                        switch part {
                        case .contracts: return .contracts(try BrokerReferenceParser.contracts(data))
                        case .margins: return .margins(try BrokerReferenceParser.margins(data))
                        case .fees: return .fees(try BrokerReferenceParser.fees(data))
                        }
                    } catch { return .failure(part, error.localizedDescription) }
                }
            }
            var update = BrokerReferenceUpdate()
            for await result in group {
                switch result {
                case .contracts(let values): update.contracts = values
                case .margins(let values): update.margins = values
                case .fees(let values): update.fees = values
                case .failure(let part, let message): update.errors[part] = message
                }
            }
            return update
        }
    }
}
