import Foundation

// MARK: - Provider Errors

public enum ProviderError: Error, Sendable {
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse(Int)        // HTTP status code
    case rateLimited
    case notFound(String)
    case unavailable(String)
}

// MARK: - PriceProvider Protocol

public protocol PriceProvider: Sendable {
    var assetClass: AssetClass { get }

    /// Fetch current quotes for the given instruments.
    /// Each returned Quote.instrument MUST be the exact Instrument passed in.
    func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote]

    /// Fetch chart data for a single instrument over a given interval.
    func chart(
        for instrument: Instrument,
        interval: ChartInterval
    ) async throws(ProviderError) -> [ChartPoint]
}

// MARK: - ChartInterval

public enum ChartInterval: String, Sendable, CaseIterable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case threeMonths = "90d"
    case year = "365d"

    public var displayName: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .year: return "1Y"
        }
    }
}
