import Foundation

// MARK: - QuoteService

/// Routes fetch requests to the appropriate provider by asset class, merges results,
/// and caches the last successful quotes.
public actor QuoteService {

    // MARK: Types

    public struct CachedQuote: Sendable {
        public let quote: Quote
        public let isStale: Bool
    }

    // MARK: State

    private let providers: [AssetClass: any PriceProvider]
    private var cache: [String: Quote] = [:]     // keyed by Instrument.id
    private let staleThreshold: TimeInterval

    // MARK: Init

    public init(
        cryptoProvider: any PriceProvider,
        vnProvider: any PriceProvider,
        intlProvider: any PriceProvider,
        staleThreshold: TimeInterval = 60
    ) {
        self.providers = [
            .crypto: cryptoProvider,
            .vnEquity: vnProvider,
            .intlEquity: intlProvider,
        ]
        self.staleThreshold = staleThreshold
    }

    // MARK: Public API

    /// Fetch quotes for the given instruments, routing by asset class.
    /// Returns a merged map of instrument ID → Quote.
    /// Providers stamp each Quote with the exact Instrument passed in, so no re-keying is needed.
    public func fetchQuotes(for instruments: [Instrument]) async -> [String: Quote] {
        // Group by asset class
        var byClass: [AssetClass: [Instrument]] = [:]
        for instrument in instruments {
            byClass[instrument.assetClass, default: []].append(instrument)
        }

        // Fetch concurrently per asset class
        await withTaskGroup(of: [Quote].self) { group in
            for (assetClass, batch) in byClass {
                guard let provider = providers[assetClass] else { continue }
                group.addTask {
                    do {
                        return try await provider.quotes(for: batch)
                    } catch {
                        return []
                    }
                }
            }
            for await quotes in group {
                for quote in quotes {
                    // Providers stamp Quote.instrument with the requested Instrument,
                    // so quote.instrument.id is already the correct cache key.
                    self.cache[quote.instrument.id] = quote
                }
            }
        }

        // Return only the quotes for the requested instruments (not all cached)
        var result: [String: Quote] = [:]
        for instrument in instruments {
            if let quote = cache[instrument.id] {
                result[instrument.id] = quote
            }
        }
        return result
    }

    /// Return cached quote if available, flagged as stale if older than threshold.
    public func cachedQuote(for instrumentID: String) -> CachedQuote? {
        guard let quote = cache[instrumentID] else { return nil }
        let isStale = Date.now.timeIntervalSince(quote.fetchedAt) > staleThreshold
        return CachedQuote(quote: quote, isStale: isStale)
    }

    /// Fetch chart points for one instrument.
    public func fetchChart(
        for instrument: Instrument,
        interval: ChartInterval
    ) async throws(ProviderError) -> [ChartPoint] {
        guard let provider = providers[instrument.assetClass] else {
            throw .unavailable("No provider for \(instrument.assetClass)")
        }
        return try await provider.chart(for: instrument, interval: interval)
    }

    /// Expose current cache (for portfolio P/L).
    public var cachedQuotes: [String: Quote] { cache }
}
