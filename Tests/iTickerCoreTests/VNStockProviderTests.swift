import Testing
import Foundation
@testable import iTickerCore

@Suite("VNStockProvider Tests")
struct VNStockProviderTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    @Test("Decodes TCBS quote fixture with ×1000 VND scaling")
    func decodesQuoteFixture() async throws {
        // Fixture: lastPrice=72.9 (thousands VND), priceChange=1.5 (thousands VND)
        // Expected after ×1000 scale: price=72900, change24h=1500
        let data = try loadFixture("tcbs_quote.json")
        let session = URLSession.stubbed(["second-tc-price": (data, 200)])

        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        let quotes = try await provider.quotes(for: [fpt])
        #expect(quotes.count == 1)
        #expect(quotes[0].instrument.symbol == "FPT")
        // 72.9 * 1000 = 72900
        #expect(abs(quotes[0].price - 72900.0) < 0.01)
        // 1.5 * 1000 = 1500
        let change = try #require(quotes[0].change24h)
        #expect(abs(change - 1500.0) < 0.01)
        // changePct is ratio * 100 — NOT scaled
        #expect(quotes[0].changePct24h != nil)
        #expect(abs(quotes[0].changePct24h! - 2.10) < 0.01)
        // currency must be VND
        #expect(quotes[0].currency == "VND")
    }

    @Test("TCBS chart fixture: OHLC values scaled ×1000")
    func decodesChartFixtureScaled() async throws {
        // Fixture closes: [71.5, 72.0, 72.9] (thousands VND)
        // Expected scaled: [71500, 72000, 72900]
        let data = try loadFixture("tcbs_chart.json")
        let session = URLSession.stubbed(["bars-long-term": (data, 200)])

        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        let points = try await provider.chart(for: fpt, interval: .month)
        #expect(points.count == 3)
        #expect(abs(points[0].close - 71500.0) < 0.01)
        #expect(abs(points[1].close - 72000.0) < 0.01)
        #expect(abs(points[2].close - 72900.0) < 0.01)
        // Volume is NOT scaled
        #expect(points[2].volume == 950000.0)
        // open/high/low also scaled
        let open0 = try #require(points[0].open)
        #expect(abs(open0 - 71000.0) < 0.01)
    }

    @Test("Returns empty for empty input")
    func emptyInput() async throws {
        let session = URLSession.stubbed([:])
        let provider = VNStockProvider(session: session)
        let quotes = try await provider.quotes(for: [])
        #expect(quotes.isEmpty)
    }

    @Test("Throws networkError on connection failure")
    func throwsNetworkError() async throws {
        // No matching stub → StubURLProtocol returns a network error
        let session = URLSession.stubbed(["__nomatch__": (Data(), 200)])

        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        do {
            _ = try await provider.quotes(for: [fpt])
            Issue.record("Expected networkError")
        } catch ProviderError.networkError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws invalidResponse on non-200")
    func throwsInvalidResponse() async throws {
        let session = URLSession.stubbed(["second-tc-price": (Data(), 503)])

        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        do {
            _ = try await provider.quotes(for: [fpt])
            Issue.record("Expected invalidResponse")
        } catch ProviderError.invalidResponse(let code) {
            #expect(code == 503)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
