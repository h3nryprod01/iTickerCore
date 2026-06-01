import Testing
import Foundation
@testable import iTickerCore

// MARK: - Fake provider for testing

private struct FakeProvider: PriceProvider {
    let assetClass: AssetClass
    let quotesToReturn: [Quote]
    let chartToReturn: [ChartPoint]

    func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        quotesToReturn
    }

    func chart(for instrument: Instrument, interval: ChartInterval) async throws(ProviderError) -> [ChartPoint] {
        chartToReturn
    }
}

private struct FailingProvider: PriceProvider {
    let assetClass: AssetClass

    func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        throw .unavailable("Test failure")
    }

    func chart(for instrument: Instrument, interval: ChartInterval) async throws(ProviderError) -> [ChartPoint] {
        throw .unavailable("Test failure")
    }
}

// MARK: - Tests

@Suite("QuoteService Tests")
struct QuoteServiceTests {

    let btcInstrument = Instrument(
        id: "bitcoin",
        symbol: "BTC",
        name: "Bitcoin",
        assetClass: .crypto,
        providerID: "bitcoin"
    )

    let fptInstrument = Instrument(
        id: "FPT",
        symbol: "FPT",
        name: "FPT Corp",
        assetClass: .vnEquity,
        providerID: "FPT"
    )

    @Test("Routes crypto instruments to crypto provider")
    func routesCryptoToProvider() async {
        let btcQuote = Quote(instrument: btcInstrument, price: 67000)
        let fakeProvider = FakeProvider(assetClass: .crypto, quotesToReturn: [btcQuote], chartToReturn: [])
        let emptyVN = FakeProvider(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(
            cryptoProvider: fakeProvider,
            vnProvider: emptyVN,
            intlProvider: emptyIntl
        )

        let quotes = await service.fetchQuotes(for: [btcInstrument])
        #expect(quotes["bitcoin"] != nil)
        #expect(quotes["bitcoin"]!.price == 67000)
    }

    @Test("Routes VN instruments to VN provider")
    func routesVNToProvider() async {
        let fptQuote = Quote(instrument: fptInstrument, price: 97500)
        let emptyCrypto = FakeProvider(assetClass: .crypto, quotesToReturn: [], chartToReturn: [])
        let fakeVN = FakeProvider(assetClass: .vnEquity, quotesToReturn: [fptQuote], chartToReturn: [])
        let emptyIntl = FakeProvider(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(
            cryptoProvider: emptyCrypto,
            vnProvider: fakeVN,
            intlProvider: emptyIntl
        )

        let quotes = await service.fetchQuotes(for: [fptInstrument])
        #expect(quotes["FPT"] != nil)
        #expect(quotes["FPT"]!.price == 97500)
    }

    @Test("Handles provider failure gracefully")
    func handlesProviderFailure() async {
        let failing = FailingProvider(assetClass: .crypto)
        let emptyVN = FakeProvider(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(
            cryptoProvider: failing,
            vnProvider: emptyVN,
            intlProvider: emptyIntl
        )

        // Should not throw — failure is swallowed and returns empty
        let quotes = await service.fetchQuotes(for: [btcInstrument])
        #expect(quotes.isEmpty)
    }

    @Test("Computes portfolio P/L with cached quotes")
    func portfolioPLWithCachedQuotes() async {
        let btcQuote = Quote(instrument: btcInstrument, price: 60_000)
        let fakeProvider = FakeProvider(assetClass: .crypto, quotesToReturn: [btcQuote], chartToReturn: [])
        let emptyVN = FakeProvider(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(
            cryptoProvider: fakeProvider,
            vnProvider: emptyVN,
            intlProvider: emptyIntl
        )

        _ = await service.fetchQuotes(for: [btcInstrument])

        let holdings = [HoldingDTO(instrument: btcInstrument, quantity: 1.0, averageCost: 50_000)]
        let cached = await service.cachedQuotes
        let pl = PLMath.portfolioTotal(holdings: holdings, quotes: cached)

        #expect(pl.unrealizedPL == 10_000)
        #expect(abs(pl.unrealizedPLPct - 20.0) < 0.001)
    }

    @Test("Cached quote is marked stale after threshold")
    func cachedQuoteIsStale() async {
        let btcQuote = Quote(
            instrument: btcInstrument,
            price: 67000,
            fetchedAt: Date(timeIntervalSinceNow: -120)   // 2 minutes ago
        )
        let fakeProvider = FakeProvider(assetClass: .crypto, quotesToReturn: [btcQuote], chartToReturn: [])
        let emptyVN = FakeProvider(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(
            cryptoProvider: fakeProvider,
            vnProvider: emptyVN,
            intlProvider: emptyIntl,
            staleThreshold: 60   // stale after 60s
        )

        _ = await service.fetchQuotes(for: [btcInstrument])
        let cached = await service.cachedQuote(for: "bitcoin")
        #expect(cached?.isStale == true)
    }
}
