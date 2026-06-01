import Testing
import Foundation
@testable import iTickerCore

@Suite("CryptoProvider Tests")
struct CryptoProviderTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: Quotes

    @Test("Decodes markets fixture into quotes")
    func decodesMarketsFixture() async throws {
        let data = try loadFixture("coingecko_markets.json")
        let session = URLSession.stubbed(["coins/markets": (data, 200)])

        let provider = CryptoProvider(
            session: session,
            baseURL: URL(string: "https://fake.coingecko.test/api/v3")!
        )

        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")
        let ethereum = Instrument(id: "ethereum", symbol: "ETH", name: "Ethereum", assetClass: .crypto, providerID: "ethereum")
        let quotes = try await provider.quotes(for: [bitcoin, ethereum])
        #expect(quotes.count == 2)

        let btc = quotes.first(where: { $0.instrument.id == "bitcoin" })
        #expect(btc != nil)
        #expect(btc!.price == 67234.0)
        #expect(btc!.changePct24h != nil)
        #expect(abs(btc!.changePct24h! - 1.87) < 0.001)
    }

    @Test("Returns empty for empty input")
    func emptyInput() async throws {
        let session = URLSession.stubbed([:])
        let provider = CryptoProvider(session: session)
        let quotes = try await provider.quotes(for: [])
        #expect(quotes.isEmpty)
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimited() async throws {
        let session = URLSession.stubbed(["coins/markets": (Data(), 429)])
        let provider = CryptoProvider(
            session: session,
            baseURL: URL(string: "https://fake.coingecko.test/api/v3")!
        )
        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")

        do {
            _ = try await provider.quotes(for: [bitcoin])
            Issue.record("Expected rateLimited error")
        } catch ProviderError.rateLimited {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: Chart

    @Test("Decodes chart fixture into ChartPoints")
    func decodesChartFixture() async throws {
        let data = try loadFixture("coingecko_chart.json")
        let session = URLSession.stubbed(["market_chart": (data, 200)])

        let provider = CryptoProvider(
            session: session,
            baseURL: URL(string: "https://fake.coingecko.test/api/v3")!
        )

        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")
        let points = try await provider.chart(for: bitcoin, interval: .week)
        #expect(points.count == 5)
        #expect(points[0].close == 37000.0)
        #expect(points[4].close == 38400.0)
    }
}

enum FixtureError: Error {
    case notFound(String)
}
