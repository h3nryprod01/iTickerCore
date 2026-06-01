import Foundation

// MARK: - FallbackProvider

/// Wraps an ordered list of providers sharing the same assetClass.
/// Tries each in order; moves to the next if the current throws or returns empty.
/// Returns the first non-empty success. If all fail, throws the last ProviderError.
public struct FallbackProvider: PriceProvider {

    public let assetClass: AssetClass
    private let providers: [any PriceProvider]

    /// - Parameter providers: Ordered list; all must share the same assetClass.
    public init(_ providers: [any PriceProvider]) {
        precondition(!providers.isEmpty, "FallbackProvider requires at least one provider")
        let first = providers[0].assetClass
        for p in providers {
            precondition(
                p.assetClass == first,
                "All providers in FallbackProvider must share the same assetClass; got \(p.assetClass) and \(first)"
            )
        }
        self.assetClass = first
        self.providers = providers
    }

    // MARK: Quotes

    public func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        guard !instruments.isEmpty else { return [] }
        var lastError: ProviderError = .unavailable("No providers available")
        for provider in providers {
            do {
                let result = try await provider.quotes(for: instruments)
                if !result.isEmpty { return result }
                // Empty result — try next provider
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    // MARK: Chart

    public func chart(
        for instrument: Instrument,
        interval: ChartInterval
    ) async throws(ProviderError) -> [ChartPoint] {
        var lastError: ProviderError = .unavailable("No providers available")
        for provider in providers {
            do {
                let result = try await provider.chart(for: instrument, interval: interval)
                if !result.isEmpty { return result }
                // Empty result — try next provider
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
