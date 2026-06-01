import Testing
import Foundation
@testable import iTickerCore

// MARK: - Mock crypto providers for FallbackProvider crypto chain tests

private struct MockCryptoProvider: PriceProvider {
    let assetClass: AssetClass = .crypto
    let quotesResult: Result<[Quote], ProviderError>
    let chartResult: Result<[ChartPoint], ProviderError>

    init(
        quotes: Result<[Quote], ProviderError> = .success([]),
        chart: Result<[ChartPoint], ProviderError> = .success([])
    ) {
        self.quotesResult = quotes
        self.chartResult = chart
    }

    func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        switch quotesResult {
        case .success(let q): return q
        case .failure(let e): throw e
        }
    }

    func chart(for instrument: Instrument, interval: ChartInterval) async throws(ProviderError) -> [ChartPoint] {
        switch chartResult {
        case .success(let c): return c
        case .failure(let e): throw e
        }
    }
}

private func makeCryptoQuote(instrument: Instrument, price: Double = 60_000) -> Quote {
    Quote(instrument: instrument, price: price)
}

// MARK: - Crypto FallbackProvider Tests

@Suite("Crypto FallbackProvider Chain Tests")
struct CryptoFallbackTests {

    private let btc = Instrument(
        id: "bitcoin", symbol: "BTC", name: "Bitcoin",
        assetClass: .crypto, providerID: "bitcoin"
    )

    @Test("CoinGecko primary succeeds — Binance not called")
    func primarySucceeds() async throws {
        let btcQuote = makeCryptoQuote(instrument: btc)
        let coinGecko = MockCryptoProvider(quotes: .success([btcQuote]))
        let binance = MockCryptoProvider(quotes: .failure(.unavailable("should not be called")))
        let coinCap = MockCryptoProvider(quotes: .failure(.unavailable("should not be called")))

        let fallback = FallbackProvider([coinGecko, binance, coinCap])
        let results = try await fallback.quotes(for: [btc])

        #expect(results.count == 1)
        #expect(results[0].instrument.id == "bitcoin")
        #expect(results[0].price == 60_000)
    }

    @Test("CoinGecko throws → Binance succeeds")
    func primaryThrowsBinanceSucceeds() async throws {
        let btcQuote = makeCryptoQuote(instrument: btc, price: 61_000)
        let coinGecko = MockCryptoProvider(quotes: .failure(.rateLimited))
        let binance = MockCryptoProvider(quotes: .success([btcQuote]))
        let coinCap = MockCryptoProvider(quotes: .failure(.unavailable("should not be called")))

        let fallback = FallbackProvider([coinGecko, binance, coinCap])
        let results = try await fallback.quotes(for: [btc])

        #expect(results.count == 1)
        #expect(results[0].price == 61_000)
    }

    @Test("CoinGecko throws, Binance returns empty → CoinCap succeeds")
    func binanceEmptyCoinCapSucceeds() async throws {
        let btcQuote = makeCryptoQuote(instrument: btc, price: 62_000)
        let coinGecko = MockCryptoProvider(quotes: .failure(.rateLimited))
        let binance = MockCryptoProvider(quotes: .success([]))
        let coinCap = MockCryptoProvider(quotes: .success([btcQuote]))

        let fallback = FallbackProvider([coinGecko, binance, coinCap])
        let results = try await fallback.quotes(for: [btc])

        #expect(results.count == 1)
        #expect(results[0].price == 62_000)
    }

    @Test("All three fail → throws last error")
    func allFailThrowsLastError() async throws {
        let coinGecko = MockCryptoProvider(quotes: .failure(.rateLimited))
        let binance = MockCryptoProvider(quotes: .failure(.unavailable("Binance down")))
        let coinCap = MockCryptoProvider(quotes: .failure(.unavailable("CoinCap down")))

        let fallback = FallbackProvider([coinGecko, binance, coinCap])

        do {
            _ = try await fallback.quotes(for: [btc])
            Issue.record("Expected error to be thrown")
        } catch ProviderError.unavailable(let msg) {
            #expect(msg == "CoinCap down")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Chart: primary throws → fallback succeeds")
    func chartPrimaryThrowsFallbackSucceeds() async throws {
        let point = ChartPoint(timestamp: Date(), close: 61_000)
        let coinGecko = MockCryptoProvider(chart: .failure(.rateLimited))
        let binance = MockCryptoProvider(chart: .success([point]))
        let coinCap = MockCryptoProvider(chart: .failure(.unavailable("not needed")))

        let fallback = FallbackProvider([coinGecko, binance, coinCap])
        let points = try await fallback.chart(for: btc, interval: .day)

        #expect(points.count == 1)
        #expect(points[0].close == 61_000)
    }

    @Test("assetClass of crypto fallback chain is .crypto")
    func exposesCorrectAssetClass() {
        let p1 = MockCryptoProvider()
        let p2 = MockCryptoProvider()
        let p3 = MockCryptoProvider()
        let fallback = FallbackProvider([p1, p2, p3])
        #expect(fallback.assetClass == .crypto)
    }
}
