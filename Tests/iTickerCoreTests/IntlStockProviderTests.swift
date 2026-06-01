import Testing
import Foundation
@testable import iTickerCore

@Suite("IntlStockProvider Tests")
struct IntlStockProviderTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    @Test("Decodes Yahoo chart fixture into ChartPoints")
    func decodesChartFixture() async throws {
        let data = try loadFixture("yahoo_chart.json")
        // Match any yahoo chart path
        let session = URLSession.stubbed(["finance/chart": (data, 200)])

        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        let points = try await provider.chart(for: aapl, interval: .day)
        #expect(points.count == 4)
        #expect(points[3].close == 189.5)
        #expect(points[0].open != nil)
    }

    @Test("Returns quote with regularMarketPrice and computed change%")
    func returnsQuoteWithChangePercent() async throws {
        let data = try loadFixture("yahoo_chart.json")
        let session = URLSession.stubbed(["finance/chart": (data, 200)])

        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        let quotes = try await provider.quotes(for: [aapl])
        #expect(quotes.count == 1)
        #expect(quotes[0].instrument.symbol == "AAPL")
        // regularMarketPrice = 189.5 from fixture
        #expect(quotes[0].price == 189.5)
        // change24h = 189.5 - 187.0 = 2.5
        #expect(quotes[0].change24h == 2.5)
        // changePct24h = (2.5 / 187.0) * 100 ≈ 1.3369
        let pct = try #require(quotes[0].changePct24h)
        #expect(abs(pct - (2.5 / 187.0 * 100)) < 0.001)
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimited() async throws {
        let session = URLSession.stubbed(["finance/chart": (Data(), 429)])

        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        do {
            _ = try await provider.quotes(for: [aapl])
            Issue.record("Expected rateLimited error")
        } catch ProviderError.rateLimited {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Returns empty for empty input")
    func returnsEmptyForEmptyInput() async throws {
        let session = URLSession.stubbed([:])
        let provider = IntlStockProvider(session: session)
        let quotes = try await provider.quotes(for: [])
        #expect(quotes.isEmpty)
    }

    // MARK: - Negative change% (price < previousClose)

    @Test("Returns negative change and changePct when price is below previousClose")
    func returnsNegativeChangePct() async throws {
        // Fixture: regularMarketPrice = 180.0, previousClose = 195.0
        // change24h = 180.0 - 195.0 = -15.0
        // changePct24h = (-15.0 / 195.0) * 100 ≈ -7.6923%
        let data = try loadFixture("yahoo_chart_negative.json")
        let session = URLSession.stubbed(["finance/chart": (data, 200)])

        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let tsla = Instrument(id: "TSLA", symbol: "TSLA", name: "Tesla Inc", assetClass: .intlEquity, providerID: "TSLA")
        let quotes = try await provider.quotes(for: [tsla])
        #expect(quotes.count == 1)
        #expect(quotes[0].price == 180.0)

        let change = try #require(quotes[0].change24h)
        #expect(change == -15.0)

        let pct = try #require(quotes[0].changePct24h)
        #expect(pct < 0, "changePct24h must be negative when price < previousClose")
        #expect(abs(pct - (-15.0 / 195.0 * 100)) < 0.001)
    }

    @Test("Symbol name comes from shortName in fixture")
    func symbolNameFromShortName() async throws {
        let data = try loadFixture("yahoo_chart.json")
        let session = URLSession.stubbed(["finance/chart": (data, 200)])

        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        let quotes = try await provider.quotes(for: [aapl])
        #expect(quotes.count == 1)
        // The instrument is stamped with the exact requested Instrument, not the Yahoo-parsed name
        #expect(quotes[0].instrument.name == "Apple Inc")
    }

    @Test("USD fixture produces currency == USD")
    func usdFixtureCurrency() async throws {
        let data = try loadFixture("yahoo_chart.json")
        let session = URLSession.stubbed(["finance/chart": (data, 200)])
        let provider = IntlStockProvider(session: session, baseURL: URL(string: "https://fake.yahoo.test")!)
        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        let quotes = try await provider.quotes(for: [aapl])
        #expect(quotes.count == 1)
        #expect(quotes[0].currency == "USD")
    }

    @Test("EUR fixture produces currency == EUR")
    func eurFixtureCurrency() async throws {
        let data = try loadFixture("yahoo_chart_eur.json")
        let session = URLSession.stubbed(["finance/chart": (data, 200)])
        let provider = IntlStockProvider(session: session, baseURL: URL(string: "https://fake.yahoo.test")!)
        let airbus = Instrument(id: "AIR.PA", symbol: "AIR.PA", name: "Airbus SE", assetClass: .intlEquity, providerID: "AIR.PA")
        let quotes = try await provider.quotes(for: [airbus])
        #expect(quotes.count == 1)
        #expect(quotes[0].currency == "EUR")
        #expect(abs(quotes[0].price - 165.32) < 0.001)
    }

    @Test("Missing currency field falls back to USD")
    func missingCurrencyFallsBackToUSD() async throws {
        // yahoo_chart_negative.json has no currency field initially but now has "USD"
        // Use a hand-crafted fixture with the field absent to test the fallback
        let noCurrencyJSON = """
        {"chart":{"result":[{"meta":{"symbol":"TEST","regularMarketPrice":100.0,"previousClose":99.0},"timestamp":[1700000000],"indicators":{"quote":[{"open":[99.5],"high":[101.0],"low":[99.0],"close":[100.0],"volume":[1000000]}]}}],"error":null}}
        """.data(using: .utf8)!
        let session = URLSession.stubbed(["finance/chart": (noCurrencyJSON, 200)])
        let provider = IntlStockProvider(session: session, baseURL: URL(string: "https://fake.yahoo.test")!)
        let test = Instrument(id: "TEST", symbol: "TEST", name: "Test Corp", assetClass: .intlEquity, providerID: "TEST")
        let quotes = try await provider.quotes(for: [test])
        #expect(quotes.count == 1)
        #expect(quotes[0].currency == "USD")
    }
}
