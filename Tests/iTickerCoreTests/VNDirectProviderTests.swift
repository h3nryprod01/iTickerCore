import Testing
import Foundation
@testable import iTickerCore

@Suite("VNDirectProvider Tests")
struct VNDirectProviderTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    @Test("Decodes ok history fixture into quote with correct last-close and change%")
    func decodesOkFixture() async throws {
        let data = try loadFixture("vndirect_history.json")
        // Match any path containing "dchart/history"
        let session = URLSession.stubbed(["dchart/history": (data, 200)])

        let provider = VNDirectProvider(
            session: session,
            baseURL: URL(string: "https://fake.vndirect.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        let quotes = try await provider.quotes(for: [fpt])
        #expect(quotes.count == 1)
        let quote = quotes[0]
        #expect(quote.instrument.symbol == "FPT")
        // Fixture c=[72.5, 72.9]; VNDirect returns thousands-VND → ×1000 scaling applied.
        // Last close: 72.9 × 1000 = 72900
        #expect(quote.price == 72900.0)
        // change24h = (72.9 - 72.5) × 1000 = 400
        let change = try #require(quote.change24h)
        #expect(abs(change - 400.0) < 0.001)
        // changePct24h = 400 / 72500 × 100 (ratio, not scaled)
        let pct = try #require(quote.changePct24h)
        #expect(abs(pct - (400.0 / 72500.0 * 100)) < 0.001)
        // volume24h = last v value = 2345678.0 (volume is share count, not scaled)
        #expect(quote.volume24h == 2345678.0)
        // VNDirect returns thousands-VND scaled to full VND; currency must be VND
        #expect(quote.currency == "VND")
    }

    @Test("Decodes chart fixture into ChartPoints")
    func decodesChartFixture() async throws {
        let data = try loadFixture("vndirect_history.json")
        let session = URLSession.stubbed(["dchart/history": (data, 200)])

        let provider = VNDirectProvider(
            session: session,
            baseURL: URL(string: "https://fake.vndirect.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        let points = try await provider.chart(for: fpt, interval: .week)
        #expect(points.count == 2)
        // Fixture c=[72.5, 72.9], o=[72.0, 72.5] → scaled ×1000
        #expect(points[1].close == 72900.0)
        #expect(points[0].open == 72000.0)
    }

    @Test("Throws notFound when s is no_data")
    func throwsNotFoundOnNoData() async throws {
        let data = try loadFixture("vndirect_no_data.json")
        let session = URLSession.stubbed(["dchart/history": (data, 200)])

        let provider = VNDirectProvider(
            session: session,
            baseURL: URL(string: "https://fake.vndirect.test")!
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
        let badData = "not json at all".data(using: .utf8)!
        let session = URLSession.stubbed(["dchart/history": (badData, 200)])

        let provider = VNDirectProvider(
            session: session,
            baseURL: URL(string: "https://fake.vndirect.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        do {
            _ = try await provider.quotes(for: [fpt])
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimitedOn429() async throws {
        let session = URLSession.stubbed(["dchart/history": (Data(), 429)])

        let provider = VNDirectProvider(
            session: session,
            baseURL: URL(string: "https://fake.vndirect.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        do {
            _ = try await provider.quotes(for: [fpt])
            Issue.record("Expected rateLimited error")
        } catch ProviderError.rateLimited {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Returns empty for empty input")
    func emptyInputReturnsEmpty() async throws {
        let session = URLSession.stubbed([:])
        let provider = VNDirectProvider(session: session)
        let quotes = try await provider.quotes(for: [])
        #expect(quotes.isEmpty)
    }
}
