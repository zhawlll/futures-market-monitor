import Foundation
import CoreFoundation

enum CatalogParser {
    static func parse(_ data: Data) throws -> [Instrument] {
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        guard let decoded = String(data: data, encoding: String.Encoding(rawValue: gb)) ?? String(data: data, encoding: .utf8) else {
            throw QuoteError.invalidResponse
        }
        let text = decoded.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
        let lines = try NSRegularExpression(pattern: "(?m)^\\s*(czce|dce|shfe|cffex|gfex)\\s*:")
        let rowPattern = try NSRegularExpression(pattern: "\\[\\s*'([^']+)'\\s*,\\s*'([^']+)'([^\\]]*)\\]")
        let fields = try NSRegularExpression(pattern: "'([^']*)'")
        let source = text as NSString
        let matches = lines.matches(in: text, range: NSRange(location: 0, length: source.length))
        var result: [Instrument] = []
        for (index, line) in matches.enumerated() {
            let end = index + 1 < matches.count ? matches[index + 1].range.location : (source.range(of: "};", options: [], range: NSRange(location: line.range.location, length: source.length - line.range.location)).location)
            guard end != NSNotFound else { continue }
            let section = source.substring(with: NSRange(location: line.range.location, length: end - line.range.location))
            let sectionNS = section as NSString
            let exchange = source.substring(with: line.range(at: 1)).uppercased()
            for row in rowPattern.matches(in: section, range: NSRange(location: 0, length: sectionNS.length)) {
                let tail = sectionNS.substring(with: row.range(at: 3))
                let tailNS = tail as NSString
                let extras = fields.matches(in: tail, range: NSRange(location: 0, length: tailNS.length)).map { tailNS.substring(with: $0.range(at: 1)) }
                result.append(Instrument(id: sectionNS.substring(with: row.range(at: 2)),
                                         name: sectionNS.substring(with: row.range(at: 1)), exchange: exchange,
                                         base: extras.count > 1 ? extras[1] : "futures"))
            }
        }
        guard !result.isEmpty else { throw QuoteError.empty }
        var ids = Set<String>()
        return result.filter { ids.insert($0.id).inserted }
    }
}
