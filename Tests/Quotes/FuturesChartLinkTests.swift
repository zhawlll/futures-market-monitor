import Foundation
import Testing
@testable import FuturesMonitorCore

struct FuturesChartLinkTests {
    @Test func everyBundledInstrumentHasChartBeforeFirstQuote() throws {
        for source in ["catalog", "catalog-eastmoney"] {
            for instrument in try Fixtures.catalog(source) {
                let url = try #require(FuturesChartLink.url(for: instrument), Comment(rawValue: instrument.id))
                #expect(url.scheme == "https")
                #expect(url.host == (instrument.dataSource == .sina ? "finance.sina.com.cn" : "quote.eastmoney.com"))
            }
        }
    }

    @Test(arguments: [(Fixtures.emLH, "lhm.html"), (Fixtures.emLC, "lcm.html"),
                      (Fixtures.lh, "LH0.shtml"), (Fixtures.lc, "LC0.shtml"),
                      (Instrument(id: "qz_qh", name: "沪深300", exchange: "CFFEX", base: "futuresindex"), "IF0.shtml"),
                      (Instrument(id: "pta_qh", name: "PTA", exchange: "CZCE", base: "futures"), "TA0.shtml"),
                      (Instrument(id: "em:220.ICM", name: "中证500", exchange: "CFFEX", base: "eastmoney"), "ICM.html")])
    func routesContinuousInsteadOfNodeOrMonth(instrument: Instrument, page: String) {
        #expect(FuturesChartLink.url(for: instrument, quoteSymbol: "LC2701")?.lastPathComponent == page)
    }

    @Test func newSinaProductRequiresValidContinuousSymbol() {
        let unknown = Instrument(id: "new_qh", name: "新品种", exchange: "GFEX", base: "gfuturesindex")
        #expect(FuturesChartLink.url(for: unknown) == nil)
        #expect(FuturesChartLink.url(for: unknown, quoteSymbol: "NEW2701") == nil)
        #expect(FuturesChartLink.url(for: unknown, quoteSymbol: "../../example") == nil)
        #expect(FuturesChartLink.url(for: unknown, quoteSymbol: "NEW0")?.lastPathComponent == "NEW0.shtml")
    }
}
