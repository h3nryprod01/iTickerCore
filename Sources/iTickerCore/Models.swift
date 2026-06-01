import Foundation

// MARK: - AssetClass

public enum AssetClass: String, Codable, Sendable, CaseIterable {
    case crypto = "crypto"
    case vnEquity = "vnEquity"
    case intlEquity = "intlEquity"

    public var displayName: String {
        switch self {
        case .crypto: return "Crypto"
        case .vnEquity: return "VN Equity"
        case .intlEquity: return "Intl Equity"
        }
    }

    /// Default ISO 4217 currency code for instruments in this asset class.
    /// Used when no live quote (and thus no quote.currency) is available.
    public var defaultCurrencyCode: String {
        switch self {
        case .crypto:      return "USD"
        case .intlEquity:  return "USD"
        case .vnEquity:    return "VND"
        }
    }
}

// MARK: - Instrument

public struct Instrument: Codable, Sendable, Hashable, Identifiable {
    public let id: String           // Unique: "BTC", "FPT.VN", "AAPL"
    public let symbol: String       // Display symbol
    public let name: String
    public let assetClass: AssetClass
    public let providerID: String   // e.g. CoinGecko id "bitcoin"
    /// ISO 4217 currency code for the instrument's native price.
    /// Defaults to `assetClass.defaultCurrencyCode` when not explicitly provided.
    public let currencyCode: String

    public init(
        id: String,
        symbol: String,
        name: String,
        assetClass: AssetClass,
        providerID: String,
        currencyCode: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.assetClass = assetClass
        self.providerID = providerID
        self.currencyCode = currencyCode ?? assetClass.defaultCurrencyCode
    }
}

// MARK: - Quote

public struct Quote: Sendable {
    public let instrument: Instrument
    public let price: Double
    public let change24h: Double?         // Absolute change
    public let changePct24h: Double?      // Percent change
    public let volume24h: Double?
    public let fetchedAt: Date
    /// ISO 4217 currency code for the native price, e.g. "USD", "VND", "EUR".
    /// Defaults to "USD" for backward compatibility.
    public let currency: String

    public init(
        instrument: Instrument,
        price: Double,
        change24h: Double? = nil,
        changePct24h: Double? = nil,
        volume24h: Double? = nil,
        fetchedAt: Date = .now,
        currency: String = "USD"
    ) {
        self.instrument = instrument
        self.price = price
        self.change24h = change24h
        self.changePct24h = changePct24h
        self.volume24h = volume24h
        self.fetchedAt = fetchedAt
        self.currency = currency
    }
}

// MARK: - ChartPoint

public struct ChartPoint: Sendable {
    public let timestamp: Date
    public let close: Double
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let volume: Double?

    public init(
        timestamp: Date,
        close: Double,
        open: Double? = nil,
        high: Double? = nil,
        low: Double? = nil,
        volume: Double? = nil
    ) {
        self.timestamp = timestamp
        self.close = close
        self.open = open
        self.high = high
        self.low = low
        self.volume = volume
    }
}

// MARK: - HoldingDTO

/// Plain value type for P/L math — no SwiftData dependency.
public struct HoldingDTO: Sendable {
    public let instrument: Instrument
    public let quantity: Double
    public let averageCost: Double    // Cost per unit in display currency

    public init(instrument: Instrument, quantity: Double, averageCost: Double) {
        self.instrument = instrument
        self.quantity = quantity
        self.averageCost = averageCost
    }
}
