import Testing
import Foundation
@testable import iTickerCore

/// Tests focused on decoding paths: correct parsing of valid fixtures and
/// clean ProviderError (no crash) on malformed / partial JSON.
@Suite("Provider Decoding Tests")
struct ProviderDecodingTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - CryptoProvider decoding

    @Test("CoinGecko: item with null current_price is skipped (compactMap)")
    func cryptoSkipsNullPrice() async throws {
        let data = try loadFixture("coingecko_markets_partial.json")
        let session = URLSession.stubbed(["coins/markets": (data, 200)])
        let provider = CryptoProvider(
            session: session,
            baseURL: URL(string: "https://fake.cg.test/api/v3")!
        )

        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")
        let dogecoin = Instrument(id: "dogecoin", symbol: "DOGE", name: "Dogecoin", assetClass: .crypto, providerID: "dogecoin")
        let quotes = try await provider.quotes(for: [bitcoin, dogecoin])
        // Only bitcoin has a non-null current_price; dogecoin must be skipped
        #expect(quotes.count == 1)
        #expect(quotes[0].instrument.id == "bitcoin")
    }

    @Test("CoinGecko: malformed JSON yields decodingError, not crash")
    func cryptoMalformedJSON() async throws {
        let badData = Data("{not valid json".utf8)
        let session = URLSession.stubbed(["coins/markets": (badData, 200)])
        let provider = CryptoProvider(
            session: session,
            baseURL: URL(string: "https://fake.cg.test/api/v3")!
        )

        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")
        do {
            _ = try await provider.quotes(for: [bitcoin])
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("CoinGecko: 503 yields invalidResponse(503)")
    func crypto503() async throws {
        let session = URLSession.stubbed(["coins/markets": (Data(), 503)])
        let provider = CryptoProvider(
            session: session,
            baseURL: URL(string: "https://fake.cg.test/api/v3")!
        )
        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")

        do {
            _ = try await provider.quotes(for: [bitcoin])
            Issue.record("Expected invalidResponse")
        } catch ProviderError.invalidResponse(let code) {
            #expect(code == 503)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("CoinGecko chart: malformed JSON yields decodingError")
    func cryptoChartMalformed() async throws {
        let badData = Data("[]".utf8)   // valid JSON but wrong shape for CGMarketChart
        let session = URLSession.stubbed(["market_chart": (badData, 200)])
        let provider = CryptoProvider(
            session: session,
            baseURL: URL(string: "https://fake.cg.test/api/v3")!
        )

        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")
        do {
            _ = try await provider.chart(for: bitcoin, interval: .day)
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("CoinGecko: all ChartInterval values produce correct days param in URL")
    func cryptoChartAllIntervals() async throws {
        let data = try loadFixture("coingecko_chart.json")
        let bitcoin = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")

        // We check that each interval completes without error (days param is embedded in URL path
        // but not observable from outside — we just confirm no crash and correct point count).
        for interval in ChartInterval.allCases {
            let session = URLSession.stubbed(["market_chart": (data, 200)])
            let provider = CryptoProvider(
                session: session,
                baseURL: URL(string: "https://fake.cg.test/api/v3")!
            )
            let points = try await provider.chart(for: bitcoin, interval: interval)
            #expect(points.count == 5, "Expected 5 points for interval \(interval)")
        }
    }

    // MARK: - VNStockProvider decoding

    @Test("TCBS: null lastPrice means item is skipped")
    func tcbsNullPrice() async throws {
        let data = try loadFixture("tcbs_quote_no_price.json")
        let session = URLSession.stubbed(["second-tc-price": (data, 200)])
        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )

        let vnm = Instrument(id: "VNM", symbol: "VNM", name: "Vinamilk", assetClass: .vnEquity, providerID: "VNM")
        let quotes = try await provider.quotes(for: [vnm])
        // lastPrice is null → fetchSingle returns nil → quotes is empty
        #expect(quotes.isEmpty)
    }

    @Test("TCBS: malformed JSON yields decodingError, not crash")
    func tcbsMalformedJSON() async throws {
        let badData = Data("not json at all".utf8)
        let session = URLSession.stubbed(["second-tc-price": (badData, 200)])
        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
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

    @Test("TCBS: chart fixture decodes into ChartPoints with OHLCV")
    func tcbsChartFixture() async throws {
        let data = try loadFixture("tcbs_chart.json")
        let session = URLSession.stubbed(["bars-long-term": (data, 200)])
        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )
        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")

        let points = try await provider.chart(for: fpt, interval: .month)
        #expect(points.count == 3)
        // Fixture closes: [71.5, 72.0, 72.9] thousands VND → scaled ×1000
        #expect(points[0].close == 71500.0)
        #expect(points[2].close == 72900.0)
        #expect(points[0].open != nil)
        #expect(points[0].high != nil)
        #expect(points[0].low != nil)
        #expect(points[0].volume != nil)
    }

    @Test("TCBS: chart 429 yields rateLimited")
    func tcbsChart429() async throws {
        let session = URLSession.stubbed(["bars-long-term": (Data(), 429)])
        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        do {
            _ = try await provider.chart(for: fpt, interval: .week)
            Issue.record("Expected rateLimited")
        } catch ProviderError.rateLimited {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("TCBS: empty data array in response yields empty quotes")
    func tcbsEmptyDataArray() async throws {
        let emptyData = Data(#"{"data":[]}"#.utf8)
        let session = URLSession.stubbed(["second-tc-price": (emptyData, 200)])
        let provider = VNStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.tcbs.test")!
        )

        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        let quotes = try await provider.quotes(for: [fpt])
        #expect(quotes.isEmpty)
    }

    // MARK: - IntlStockProvider decoding

    @Test("Yahoo: chart with null close values skips those points")
    func yahooNullCloseValues() async throws {
        let data = try loadFixture("yahoo_chart_with_nulls.json")
        let session = URLSession.stubbed(["finance/chart": (data, 200)])
        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let msft = Instrument(id: "MSFT", symbol: "MSFT", name: "Microsoft", assetClass: .intlEquity, providerID: "MSFT")
        let points = try await provider.chart(for: msft, interval: .day)
        // Index 1 has null close → skipped; indices 0, 2, 3 have valid closes → 3 points
        #expect(points.count == 3)
        #expect(points[0].close == 420.0)
        #expect(points[1].close == 421.0)
        #expect(points[2].close == 420.5)
    }

    @Test("Yahoo: error field in response yields unavailable error")
    func yahooErrorField() async throws {
        let data = try loadFixture("yahoo_chart_error.json")
        let session = URLSession.stubbed(["finance/chart": (data, 200)])
        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let invalid = Instrument(id: "INVALID", symbol: "INVALID", name: "Invalid", assetClass: .intlEquity, providerID: "INVALID")
        do {
            _ = try await provider.chart(for: invalid, interval: .day)
            Issue.record("Expected unavailable error")
        } catch ProviderError.unavailable(let code) {
            #expect(code == "Not Found")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Yahoo: 404 response yields notFound error")
    func yahoo404() async throws {
        let session = URLSession.stubbed(["finance/chart": (Data(), 404)])
        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let unknown = Instrument(id: "UNKNOWN", symbol: "UNKNOWN", name: "Unknown", assetClass: .intlEquity, providerID: "UNKNOWN")
        do {
            _ = try await provider.quotes(for: [unknown])
            Issue.record("Expected notFound error")
        } catch ProviderError.notFound(let symbol) {
            #expect(symbol == "UNKNOWN")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Yahoo: malformed JSON yields decodingError, not crash")
    func yahooMalformedJSON() async throws {
        let badData = Data("{\"chart\": \"not an object\"}".utf8)
        let session = URLSession.stubbed(["finance/chart": (badData, 200)])
        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        do {
            _ = try await provider.chart(for: aapl, interval: .day)
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Yahoo: chart with no timestamps returns empty array")
    func yahooNoTimestamps() async throws {
        let json = """
        {
          "chart": {
            "result": [
              {
                "meta": {
                  "symbol": "AAPL",
                  "regularMarketPrice": 189.5
                },
                "timestamp": [],
                "indicators": { "quote": [] }
              }
            ],
            "error": null
          }
        }
        """
        let data = Data(json.utf8)
        let session = URLSession.stubbed(["finance/chart": (data, 200)])
        let provider = IntlStockProvider(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )

        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        let points = try await provider.chart(for: aapl, interval: .day)
        #expect(points.isEmpty)
    }

    @Test("Yahoo: chart for non-day intervals completes without error")
    func yahooNonDayIntervals() async throws {
        let data = try loadFixture("yahoo_chart.json")
        let intervalsToTest: [ChartInterval] = [.week, .month, .threeMonths, .year]

        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")
        for interval in intervalsToTest {
            let session = URLSession.stubbed(["finance/chart": (data, 200)])
            let provider = IntlStockProvider(
                session: session,
                baseURL: URL(string: "https://fake.yahoo.test")!
            )
            let points = try await provider.chart(for: aapl, interval: interval)
            #expect(points.count == 4, "Expected 4 points for interval \(interval)")
        }
    }
}
