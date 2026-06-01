import Testing
import Foundation
@testable import iTickerCore

@Suite("SSIProvider Tests")
struct SSIProviderTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    @Test("Decodes ok history fixture into quote with correct last-close and change%")
    func decodesOkFixture() async throws {
        let data = try loadFixture("ssi_history.json")
        // Match any path containing "statistics/charts/history"
        let session = URLSession.stubbed(["statistics/charts/history": (data, 200)])

        let provider = SSIProvider(
            session: session,
            baseURL: URL(string: "https://fake.ssi.test")!
        )

        let vic = Instrument(id: "VIC", symbol: "VIC", name: "Vingroup", assetClass: .vnEquity, providerID: "VIC")
        let quotes = try await provider.quotes(for: [vic])
        #expect(quotes.count == 1)
        let quote = quotes[0]
        #expect(quote.instrument.symbol == "VIC")
        // Fixture c=[72.5, 72.9]; SSI returns thousands-VND → ×1000 scaling applied.
        // Last close: 72.9 × 1000 = 72900
        #expect(quote.price == 72900.0)
        // change24h = (72.9 - 72.5) × 1000 = 400
        let change = try #require(quote.change24h)
        #expect(abs(change - 400.0) < 0.001)
        // changePct24h = 400 / 72500 × 100 (ratio, not scaled)
        let pct = try #require(quote.changePct24h)
        #expect(abs(pct - (400.0 / 72500.0 * 100)) < 0.001)
        // volume24h = last v value = 2345678.0 (share count, not scaled)
        #expect(quote.volume24h == 2345678.0)
        // SSI returns thousands-VND scaled to full VND; currency must be VND
        #expect(quote.currency == "VND")
    }

    @Test("Decodes chart fixture into ChartPoints")
    func decodesChartFixture() async throws {
        let data = try loadFixture("ssi_history.json")
        let session = URLSession.stubbed(["statistics/charts/history": (data, 200)])

        let provider = SSIProvider(
            session: session,
            baseURL: URL(string: "https://fake.ssi.test")!
        )

        let vic = Instrument(id: "VIC", symbol: "VIC", name: "Vingroup", assetClass: .vnEquity, providerID: "VIC")
        let points = try await provider.chart(for: vic, interval: .week)
        #expect(points.count == 2)
        // Fixture c=[72.5, 72.9] → scaled ×1000
        #expect(points[1].close == 72900.0)
    }

    @Test("Throws notFound when s is no_data")
    func throwsNotFoundOnNoData() async throws {
        let noDataJSON = """
        {"s":"no_data","t":null,"o":null,"h":null,"l":null,"c":null,"v":null}
        """.data(using: .utf8)!
        let session = URLSession.stubbed(["statistics/charts/history": (noDataJSON, 200)])

        let provider = SSIProvider(
            session: session,
            baseURL: URL(string: "https://fake.ssi.test")!
        )

        let unknown = Instrument(id: "UNKNOWN", symbol: "UNKNOWN", name: "Unknown", assetClass: .vnEquity, providerID: "UNKNOWN")
        do {
            _ = try await provider.quotes(for: [unknown])
            Issue.record("Expected notFound error")
        } catch ProviderError.notFound(let sym) {
            #expect(sym == "UNKNOWN")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws decodingError on malformed JSON")
    func throwsDecodingErrorOnBadJSON() async throws {
        let badData = "not json".data(using: .utf8)!
        let session = URLSession.stubbed(["statistics/charts/history": (badData, 200)])

        let provider = SSIProvider(
            session: session,
            baseURL: URL(string: "https://fake.ssi.test")!
        )

        let vic = Instrument(id: "VIC", symbol: "VIC", name: "Vingroup", assetClass: .vnEquity, providerID: "VIC")
        do {
            _ = try await provider.quotes(for: [vic])
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws invalidResponse on non-200")
    func throwsInvalidResponseOnNon200() async throws {
        let session = URLSession.stubbed(["statistics/charts/history": (Data(), 503)])

        let provider = SSIProvider(
            session: session,
            baseURL: URL(string: "https://fake.ssi.test")!
        )

        let vic = Instrument(id: "VIC", symbol: "VIC", name: "Vingroup", assetClass: .vnEquity, providerID: "VIC")
        do {
            _ = try await provider.quotes(for: [vic])
            Issue.record("Expected invalidResponse error")
        } catch ProviderError.invalidResponse(let code) {
            #expect(code == 503)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Returns empty for empty input")
    func emptyInputReturnsEmpty() async throws {
        let session = URLSession.stubbed([:])
        let provider = SSIProvider(session: session)
        let quotes = try await provider.quotes(for: [])
        #expect(quotes.isEmpty)
    }
}
