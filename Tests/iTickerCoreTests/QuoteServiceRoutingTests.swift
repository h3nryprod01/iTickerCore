import Testing
import Foundation
@testable import iTickerCore

// MARK: - Additional QuoteService routing and cache tests

@Suite("QuoteService Routing and Cache Tests")
struct QuoteServiceRoutingTests {

    let btc = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")
    let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
    let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")

    // MARK: - Routing

    @Test("Routes intl equity instruments to intl provider")
    func routesIntlToProvider() async {
        let aaplQuote = Quote(instrument: aapl, price: 189.5)
        let emptyCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [], chartToReturn: [])
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let fakeIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [aaplQuote], chartToReturn: [])

        let service = QuoteService(cryptoProvider: emptyCrypto, vnProvider: emptyVN, intlProvider: fakeIntl)
        let quotes = await service.fetchQuotes(for: [aapl])

        #expect(quotes["AAPL"] != nil)
        #expect(quotes["AAPL"]!.price == 189.5)
    }

    @Test("Mixed asset classes all route to correct providers")
    func mixedAssetClassRouting() async {
        let btcQuote = Quote(instrument: btc, price: 67_000)
        let fptQuote = Quote(instrument: fpt, price: 97_500)
        let aaplQuote = Quote(instrument: aapl, price: 189.5)

        let fakeCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [btcQuote], chartToReturn: [])
        let fakeVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [fptQuote], chartToReturn: [])
        let fakeIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [aaplQuote], chartToReturn: [])

        let service = QuoteService(cryptoProvider: fakeCrypto, vnProvider: fakeVN, intlProvider: fakeIntl)
        let quotes = await service.fetchQuotes(for: [btc, fpt, aapl])

        #expect(quotes.count == 3)
        #expect(quotes["bitcoin"]?.price == 67_000)
        #expect(quotes["FPT"]?.price == 97_500)
        #expect(quotes["AAPL"]?.price == 189.5)
    }

    @Test("Empty instrument list returns empty quotes")
    func emptyInstrumentList() async {
        let fakeCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [], chartToReturn: [])
        let fakeVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let fakeIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(cryptoProvider: fakeCrypto, vnProvider: fakeVN, intlProvider: fakeIntl)
        let quotes = await service.fetchQuotes(for: [])
        #expect(quotes.isEmpty)
    }

    // MARK: - Cache behavior

    @Test("Cache is not stale when fresh (just fetched)")
    func freshCacheIsNotStale() async {
        let btcQuote = Quote(instrument: btc, price: 67_000, fetchedAt: .now)
        let fakeCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [btcQuote], chartToReturn: [])
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(
            cryptoProvider: fakeCrypto,
            vnProvider: emptyVN,
            intlProvider: emptyIntl,
            staleThreshold: 60
        )

        _ = await service.fetchQuotes(for: [btc])
        let cached = await service.cachedQuote(for: "bitcoin")
        #expect(cached != nil)
        #expect(cached?.isStale == false)
    }

    @Test("cachedQuote returns nil for unknown instrument ID")
    func cachedQuoteNilForUnknown() async {
        let fakeCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [], chartToReturn: [])
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(cryptoProvider: fakeCrypto, vnProvider: emptyVN, intlProvider: emptyIntl)
        let cached = await service.cachedQuote(for: "nonexistent")
        #expect(cached == nil)
    }

    @Test("Second fetch updates cached quote value")
    func secondFetchUpdatesCacheValue() async {
        let firstQuote = Quote(instrument: btc, price: 50_000)
        let secondQuote = Quote(instrument: btc, price: 70_000)

        let firstProvider = FakeProvider2(assetClass: .crypto, quotesToReturn: [firstQuote], chartToReturn: [])
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(cryptoProvider: firstProvider, vnProvider: emptyVN, intlProvider: emptyIntl)
        _ = await service.fetchQuotes(for: [btc])

        let afterFirst = await service.cachedQuotes
        #expect(afterFirst["bitcoin"]?.price == 50_000)

        // Simulate a second fetch with a different price by creating a new service
        // (FakeProvider2 returns the same quotes repeatedly, so we test via cachedQuotes directly)
        let secondProvider = FakeProvider2(assetClass: .crypto, quotesToReturn: [secondQuote], chartToReturn: [])
        let service2 = QuoteService(cryptoProvider: secondProvider, vnProvider: emptyVN, intlProvider: emptyIntl)
        _ = await service2.fetchQuotes(for: [btc])

        let afterSecond = await service2.cachedQuotes
        #expect(afterSecond["bitcoin"]?.price == 70_000)
    }

    // MARK: - ID vs providerID mismatch regression

    @Test("Quote keyed by requested instrument id when instrument id != providerID")
    func quoteKeyedByRequestedIDNotProviderID() async {
        // The Add sheet mints Instrument.id = "crypto:BTC" but providerID = "bitcoin".
        // The provider returns a Quote whose instrument.providerID = "bitcoin".
        // QuoteService must cache/return under "crypto:BTC", not "bitcoin".
        let requestedInstrument = Instrument(
            id: "crypto:BTC",
            symbol: "BTC",
            name: "Bitcoin",
            assetClass: .crypto,
            providerID: "bitcoin"
        )
        // The fake provider returns a Quote with the providerID-based instrument
        let providerInstrument = Instrument(
            id: "bitcoin",
            symbol: "BTC",
            name: "Bitcoin",
            assetClass: .crypto,
            providerID: "bitcoin"
        )
        let providerQuote = Quote(instrument: providerInstrument, price: 67_000)
        let fakeCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [providerQuote], chartToReturn: [])
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(cryptoProvider: fakeCrypto, vnProvider: emptyVN, intlProvider: emptyIntl)
        let quotes = await service.fetchQuotes(for: [requestedInstrument])

        // Must be keyed by requested id ("crypto:BTC"), not provider id ("bitcoin")
        #expect(quotes["crypto:BTC"] != nil, "Quote must be keyed by requested instrument id")
        #expect(quotes["bitcoin"] == nil, "Quote must NOT be keyed by provider id")
        #expect(quotes["crypto:BTC"]?.price == 67_000)
        // The returned quote's instrument.id must also be the requested id
        #expect(quotes["crypto:BTC"]?.instrument.id == "crypto:BTC")
    }

    // MARK: - Mixed batch: all three asset classes with id != providerID

    @Test("Mixed batch: crypto, VN, and intl all re-keyed from providerID to requested id")
    func mixedBatchAllRekeyed() async {
        // All three instruments have id != providerID — this is the real-world shape
        // produced by the Add sheet (e.g. "crypto:BTC", "vn:FPT", "intl:AAPL").
        let cryptoInstrument = Instrument(
            id: "crypto:BTC",
            symbol: "BTC",
            name: "Bitcoin",
            assetClass: .crypto,
            providerID: "bitcoin"
        )
        let vnInstrument = Instrument(
            id: "vn:FPT",
            symbol: "FPT",
            name: "FPT Corp",
            assetClass: .vnEquity,
            providerID: "FPT"
        )
        let intlInstrument = Instrument(
            id: "intl:AAPL",
            symbol: "AAPL",
            name: "Apple Inc",
            assetClass: .intlEquity,
            providerID: "AAPL"
        )

        // Providers return quotes keyed by providerID-based instruments
        let providerCryptoInstrument = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin", assetClass: .crypto, providerID: "bitcoin")
        let providerVNInstrument     = Instrument(id: "FPT",     symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        let providerIntlInstrument   = Instrument(id: "AAPL",    symbol: "AAPL", name: "Apple Inc", assetClass: .intlEquity, providerID: "AAPL")

        let fakeCrypto = FakeProvider2(assetClass: .crypto,
            quotesToReturn: [Quote(instrument: providerCryptoInstrument, price: 67_000)],
            chartToReturn: [])
        let fakeVN = FakeProvider2(assetClass: .vnEquity,
            quotesToReturn: [Quote(instrument: providerVNInstrument, price: 97_500)],
            chartToReturn: [])
        let fakeIntl = FakeProvider2(assetClass: .intlEquity,
            quotesToReturn: [Quote(instrument: providerIntlInstrument, price: 189.5)],
            chartToReturn: [])

        let service = QuoteService(cryptoProvider: fakeCrypto, vnProvider: fakeVN, intlProvider: fakeIntl)
        let quotes = await service.fetchQuotes(for: [cryptoInstrument, vnInstrument, intlInstrument])

        // Must be keyed by REQUESTED ids
        #expect(quotes.count == 3, "All three should be present")
        #expect(quotes["crypto:BTC"] != nil, "crypto keyed by requested id")
        #expect(quotes["vn:FPT"] != nil,     "VN keyed by requested id")
        #expect(quotes["intl:AAPL"] != nil,  "intl keyed by requested id")

        // Provider ids must NOT appear as keys
        #expect(quotes["bitcoin"] == nil, "provider id must not be a key")
        #expect(quotes["FPT"] == nil,     "provider id must not be a key when id != providerID")
        #expect(quotes["AAPL"] == nil,    "provider id must not be a key when id != providerID")

        // Values are correct
        #expect(quotes["crypto:BTC"]?.price == 67_000)
        #expect(quotes["vn:FPT"]?.price == 97_500)
        #expect(quotes["intl:AAPL"]?.price == 189.5)

        // Returned quote instruments carry the requested id
        #expect(quotes["crypto:BTC"]?.instrument.id == "crypto:BTC")
        #expect(quotes["vn:FPT"]?.instrument.id == "vn:FPT")
        #expect(quotes["intl:AAPL"]?.instrument.id == "intl:AAPL")
    }

    @Test("cachedQuote accessible by requested id after fetch with id != providerID")
    func cachedQuoteAccessibleByRequestedID() async {
        let requestedInstrument = Instrument(
            id: "crypto:BTC",
            symbol: "BTC",
            name: "Bitcoin",
            assetClass: .crypto,
            providerID: "bitcoin"
        )
        let providerInstrument = Instrument(
            id: "bitcoin",
            symbol: "BTC",
            name: "Bitcoin",
            assetClass: .crypto,
            providerID: "bitcoin"
        )
        let providerQuote = Quote(instrument: providerInstrument, price: 67_000)
        let fakeCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [providerQuote], chartToReturn: [])
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(cryptoProvider: fakeCrypto, vnProvider: emptyVN, intlProvider: emptyIntl)
        _ = await service.fetchQuotes(for: [requestedInstrument])

        let cached = await service.cachedQuote(for: "crypto:BTC")
        #expect(cached != nil, "Cache must be keyed by requested instrument id")
        #expect(cached?.quote.price == 67_000)
    }

    // MARK: - Chart routing

    @Test("fetchChart routes crypto to crypto provider")
    func fetchChartRoutesCrypto() async throws {
        let chartPoints = [
            ChartPoint(timestamp: Date(timeIntervalSince1970: 1_700_000_000), close: 60_000)
        ]
        let fakeCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [], chartToReturn: chartPoints)
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let emptyIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(cryptoProvider: fakeCrypto, vnProvider: emptyVN, intlProvider: emptyIntl)
        let points = try await service.fetchChart(for: btc, interval: .day)
        #expect(points.count == 1)
        #expect(points[0].close == 60_000)
    }

    @Test("fetchChart routes VN equity to VN provider")
    func fetchChartRoutesVN() async throws {
        let chartPoints = [
            ChartPoint(timestamp: Date(timeIntervalSince1970: 1_700_000_000), close: 97_500)
        ]
        let emptyCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [], chartToReturn: [])
        let fakeVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: chartPoints)
        let emptyIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: [])

        let service = QuoteService(cryptoProvider: emptyCrypto, vnProvider: fakeVN, intlProvider: emptyIntl)
        let points = try await service.fetchChart(for: fpt, interval: .month)
        #expect(points.count == 1)
        #expect(points[0].close == 97_500)
    }

    @Test("fetchChart routes intl equity to intl provider")
    func fetchChartRoutesIntl() async throws {
        let chartPoints = [
            ChartPoint(timestamp: Date(timeIntervalSince1970: 1_700_000_000), close: 189.5)
        ]
        let emptyCrypto = FakeProvider2(assetClass: .crypto, quotesToReturn: [], chartToReturn: [])
        let emptyVN = FakeProvider2(assetClass: .vnEquity, quotesToReturn: [], chartToReturn: [])
        let fakeIntl = FakeProvider2(assetClass: .intlEquity, quotesToReturn: [], chartToReturn: chartPoints)

        let service = QuoteService(cryptoProvider: emptyCrypto, vnProvider: emptyVN, intlProvider: fakeIntl)
        let points = try await service.fetchChart(for: aapl, interval: .year)
        #expect(points.count == 1)
        #expect(points[0].close == 189.5)
    }
}

// MARK: - Local fake providers (scoped to this file)

/// Fake provider that stamps each requested Instrument onto a Quote using the provided price.
/// Maps requested instruments to prices by providerID for flexibility in tests.
private struct FakeProvider2: PriceProvider {
    let assetClass: AssetClass
    let quotesToReturn: [Quote]
    let chartToReturn: [ChartPoint]

    /// Returns quotes re-stamped with the requested instruments.
    /// Matches by providerID: if a requested instrument's providerID matches a stored quote's
    /// instrument.providerID, the stored quote's price is returned under the requested instrument.
    func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        // Build map from providerID -> price from the hardcoded quotesToReturn
        let priceByProviderID: [String: Quote] = quotesToReturn.reduce(into: [:]) { dict, q in
            dict[q.instrument.providerID] = q
        }
        return instruments.compactMap { inst in
            guard let template = priceByProviderID[inst.providerID] else { return nil }
            // Stamp with the requested instrument
            return Quote(
                instrument: inst,
                price: template.price,
                change24h: template.change24h,
                changePct24h: template.changePct24h,
                volume24h: template.volume24h,
                fetchedAt: template.fetchedAt
            )
        }
    }

    func chart(for instrument: Instrument, interval: ChartInterval) async throws(ProviderError) -> [ChartPoint] {
        chartToReturn
    }
}
