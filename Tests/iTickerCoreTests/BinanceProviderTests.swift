import Testing
import Foundation
@testable import iTickerCore

@Suite("BinanceProvider Tests")
struct BinanceProviderTests {

    private let btc = Instrument(
        id: "bitcoin", symbol: "BTC", name: "Bitcoin",
        assetClass: .crypto, providerID: "bitcoin"
    )

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Quotes

    @Test("Decodes 24hr ticker fixture into Quote with price, change%, and volume")
    func decodesTicker() async throws {
        let data = try loadFixture("binance_ticker.json")
        let session = URLSession.stubbed(["ticker/24hr": (data, 200)])

        let provider = BinanceProvider(
            session: session,
            baseURL: URL(string: "https://fake.binance.test/api/v3")!
        )

        let quotes = try await provider.quotes(for: [btc])
        #expect(quotes.count == 1)

        let quote = quotes[0]
        #expect(quote.instrument.id == "bitcoin")
        #expect(abs(quote.price - 61434.56) < 0.01)
        let changePct = try #require(quote.changePct24h)
        #expect(abs(changePct - 2.05) < 0.001)
        let volume = try #require(quote.volume24h)
        #expect(abs(volume - 75678901.23) < 1.0)
    }

    @Test("Decode seam: decodeTicker produces correct Quote from fixture")
    func decodeSeamTicker() throws {
        let data = try loadFixture("binance_ticker.json")
        let quote = try BinanceProvider.decodeTicker(data: data, instrument: btc)
        let q = try #require(quote)
        #expect(abs(q.price - 61434.56) < 0.01)
        #expect(q.instrument.id == "bitcoin")
    }

    @Test("Returns empty for empty input")
    func emptyInput() async throws {
        let session = URLSession.stubbed([:])
        let provider = BinanceProvider(session: session)
        let quotes = try await provider.quotes(for: [])
        #expect(quotes.isEmpty)
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimitedOn429() async throws {
        let session = URLSession.stubbed(["ticker/24hr": (Data(), 429)])
        let provider = BinanceProvider(
            session: session,
            baseURL: URL(string: "https://fake.binance.test/api/v3")!
        )

        do {
            _ = try await provider.quotes(for: [btc])
            Issue.record("Expected rateLimited error")
        } catch ProviderError.rateLimited {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws notFound on 400")
    func throwsNotFoundOn400() async throws {
        let session = URLSession.stubbed(["ticker/24hr": (Data(), 400)])
        let provider = BinanceProvider(
            session: session,
            baseURL: URL(string: "https://fake.binance.test/api/v3")!
        )

        do {
            _ = try await provider.quotes(for: [btc])
            Issue.record("Expected notFound error")
        } catch ProviderError.notFound {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws decodingError on malformed JSON")
    func throwsDecodingErrorOnBadJSON() async throws {
        let badData = Data("not json".utf8)
        let session = URLSession.stubbed(["ticker/24hr": (badData, 200)])
        let provider = BinanceProvider(
            session: session,
            baseURL: URL(string: "https://fake.binance.test/api/v3")!
        )

        do {
            _ = try await provider.quotes(for: [btc])
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Chart

    @Test("Decodes klines fixture into ChartPoints with OHLCV")
    func decodesKlines() async throws {
        let data = try loadFixture("binance_klines.json")
        let session = URLSession.stubbed(["klines": (data, 200)])

        let provider = BinanceProvider(
            session: session,
            baseURL: URL(string: "https://fake.binance.test/api/v3")!
        )

        let points = try await provider.chart(for: btc, interval: .day)
        #expect(points.count == 5)
        #expect(abs(points[0].close - 60800.00) < 0.01)
        #expect(abs(points[4].close - 62500.00) < 0.01)
        #expect(points[0].open != nil)
        #expect(points[0].high != nil)
        #expect(points[0].low != nil)
        #expect(points[0].volume != nil)
    }

    @Test("Decode seam: decodeKlines produces correct ChartPoints from fixture")
    func decodeSeamKlines() throws {
        let data = try loadFixture("binance_klines.json")
        let points = try BinanceProvider.decodeKlines(data: data)
        #expect(points.count == 5)
        #expect(abs(points[0].close - 60800.00) < 0.01)
    }

    @Test("Throws decodingError on malformed klines JSON")
    func throwsDecodingErrorOnBadKlinesJSON() async throws {
        let badData = Data("{\"not\": \"klines\"}".utf8)
        let session = URLSession.stubbed(["klines": (badData, 200)])
        let provider = BinanceProvider(
            session: session,
            baseURL: URL(string: "https://fake.binance.test/api/v3")!
        )

        do {
            _ = try await provider.chart(for: btc, interval: .day)
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Symbol mapping

    @Test("binanceSymbol appends USDT to uppercased symbol")
    func symbolMapping() {
        #expect(BinanceProvider.binanceSymbol(for: "BTC") == "BTCUSDT")
        #expect(BinanceProvider.binanceSymbol(for: "eth") == "ETHUSDT")
    }
}
