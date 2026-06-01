import Testing
import Foundation
@testable import iTickerCore

// MARK: - Mock Providers for FallbackProvider tests

private struct MockProvider: PriceProvider {
    let assetClass: AssetClass
    let quotesResult: Result<[Quote], ProviderError>
    let chartResult: Result<[ChartPoint], ProviderError>

    init(
        assetClass: AssetClass = .vnEquity,
        quotes: Result<[Quote], ProviderError> = .success([]),
        chart: Result<[ChartPoint], ProviderError> = .success([])
    ) {
        self.assetClass = assetClass
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

private func makeQuote(symbol: String = "TEST") -> Quote {
    let instrument = Instrument(
        id: symbol, symbol: symbol, name: symbol,
        assetClass: .vnEquity, providerID: symbol
    )
    return Quote(instrument: instrument, price: 100.0)
}

private func makeChartPoint() -> ChartPoint {
    ChartPoint(timestamp: Date(), close: 100.0)
}

// MARK: - FallbackProvider Tests

@Suite("FallbackProvider Tests")
struct FallbackProviderTests {

    // MARK: Quotes

    private static let testInstrument = Instrument(
        id: "TEST", symbol: "TEST", name: "Test", assetClass: .vnEquity, providerID: "TEST"
    )

    @Test("Returns second provider result when first throws")
    func firstThrowsSecondSucceeds() async throws {
        let quote = makeQuote()
        let primary = MockProvider(quotes: .failure(.rateLimited))
        let fallback = MockProvider(quotes: .success([quote]))
        let provider = FallbackProvider([primary, fallback])

        let results = try await provider.quotes(for: [Self.testInstrument])
        #expect(results.count == 1)
        #expect(results[0].instrument.symbol == "TEST")
    }

    @Test("Returns second provider result when first returns empty")
    func firstEmptySecondSucceeds() async throws {
        let quote = makeQuote()
        let primary = MockProvider(quotes: .success([]))
        let fallback = MockProvider(quotes: .success([quote]))
        let provider = FallbackProvider([primary, fallback])

        let results = try await provider.quotes(for: [Self.testInstrument])
        #expect(results.count == 1)
    }

    @Test("Throws last error when all providers fail")
    func allThrowPropagatesLastError() async throws {
        let primary = MockProvider(quotes: .failure(.rateLimited))
        let fallback = MockProvider(quotes: .failure(.unavailable("down")))
        let provider = FallbackProvider([primary, fallback])

        do {
            _ = try await provider.quotes(for: [Self.testInstrument])
            Issue.record("Expected error to be thrown")
        } catch ProviderError.unavailable(let msg) {
            #expect(msg == "down")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Returns first provider result when it succeeds")
    func firstSucceedsUsedDirectly() async throws {
        let quote = makeQuote(symbol: "PRIMARY")
        let primary = MockProvider(quotes: .success([quote]))
        let fallback = MockProvider(quotes: .success([makeQuote(symbol: "FALLBACK")]))
        let provider = FallbackProvider([primary, fallback])

        let primaryInstrument = Instrument(id: "PRIMARY", symbol: "PRIMARY", name: "Primary", assetClass: .vnEquity, providerID: "PRIMARY")
        let results = try await provider.quotes(for: [primaryInstrument])
        #expect(results.count == 1)
        #expect(results[0].instrument.symbol == "PRIMARY")
    }

    @Test("Returns empty for empty instruments without calling providers")
    func emptyInputReturnsEmpty() async throws {
        let primary = MockProvider(quotes: .failure(.rateLimited))
        let provider = FallbackProvider([primary])

        let results = try await provider.quotes(for: [])
        #expect(results.isEmpty)
    }

    // MARK: Chart

    @Test("Chart falls back to second provider when first throws")
    func chartFirstThrowsSecondSucceeds() async throws {
        let point = makeChartPoint()
        let primary = MockProvider(chart: .failure(.unavailable("primary down")))
        let fallback = MockProvider(chart: .success([point]))
        let provider = FallbackProvider([primary, fallback])

        let results = try await provider.chart(for: Self.testInstrument, interval: .week)
        #expect(results.count == 1)
    }

    @Test("Chart falls back to second provider when first returns empty")
    func chartFirstEmptySecondSucceeds() async throws {
        let point = makeChartPoint()
        let primary = MockProvider(chart: .success([]))
        let fallback = MockProvider(chart: .success([point]))
        let provider = FallbackProvider([primary, fallback])

        let results = try await provider.chart(for: Self.testInstrument, interval: .week)
        #expect(results.count == 1)
    }

    // MARK: assetClass

    @Test("FallbackProvider exposes first provider's assetClass")
    func exposesCorrectAssetClass() {
        let p1 = MockProvider(assetClass: .intlEquity)
        let p2 = MockProvider(assetClass: .intlEquity)
        let provider = FallbackProvider([p1, p2])
        #expect(provider.assetClass == .intlEquity)
    }
}
