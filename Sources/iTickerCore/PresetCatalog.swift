import Foundation

// MARK: - PresetCatalog

/// A static catalog of pre-defined instruments grouped by asset class.
///
/// All ids follow the `"<assetClassRaw>:<symbol>"` format that AddInstrumentSheet
/// uses, so dedupe and menu-bar toggles work correctly.
///
/// providerID conventions:
///   - crypto: CoinGecko id (lowercase, e.g. "bitcoin")
///   - vnEquity: symbol itself (e.g. "FPT")
///   - intlEquity: symbol itself (e.g. "AAPL")
public enum PresetCatalog {

    // MARK: - Public API

    /// Returns the preset instruments for the given asset class.
    public static func presets(for assetClass: AssetClass) -> [Instrument] {
        switch assetClass {
        case .crypto: return cryptoPresets
        case .vnEquity: return vnPresets
        case .intlEquity: return intlPresets
        }
    }

    /// All preset instruments across all asset classes.
    public static var all: [Instrument] {
        AssetClass.allCases.flatMap { presets(for: $0) }
    }

    /// Derives the providerID for a manually-entered instrument.
    ///
    /// Looks up the preset catalog first (case-insensitive symbol match).
    /// Falls back to:
    ///   - crypto   → `symbol.lowercased()`
    ///   - vn/intl  → `symbol` (already uppercased by the form)
    ///
    /// - Parameters:
    ///   - symbol:     The ticker symbol entered by the user (any case).
    ///   - assetClass: The asset class selected in the add form.
    /// - Returns: The best-effort providerID string.
    public static func providerID(forSymbol symbol: String, assetClass: AssetClass) -> String {
        let upper = symbol.uppercased()
        if let match = presets(for: assetClass).first(where: { $0.symbol.uppercased() == upper }) {
            return match.providerID
        }
        switch assetClass {
        case .crypto:          return symbol.lowercased()
        case .vnEquity, .intlEquity: return symbol
        }
    }

    // MARK: - Crypto (CoinGecko)

    private static let cryptoPresets: [Instrument] = [
        Instrument(id: "crypto:BTC",  symbol: "BTC",  name: "Bitcoin",   assetClass: .crypto, providerID: "bitcoin"),
        Instrument(id: "crypto:ETH",  symbol: "ETH",  name: "Ethereum",  assetClass: .crypto, providerID: "ethereum"),
        Instrument(id: "crypto:BNB",  symbol: "BNB",  name: "BNB",       assetClass: .crypto, providerID: "binancecoin"),
        Instrument(id: "crypto:SOL",  symbol: "SOL",  name: "Solana",    assetClass: .crypto, providerID: "solana"),
        Instrument(id: "crypto:XRP",  symbol: "XRP",  name: "XRP",       assetClass: .crypto, providerID: "ripple"),
        Instrument(id: "crypto:ADA",  symbol: "ADA",  name: "Cardano",   assetClass: .crypto, providerID: "cardano"),
        Instrument(id: "crypto:DOGE", symbol: "DOGE", name: "Dogecoin",  assetClass: .crypto, providerID: "dogecoin"),
        Instrument(id: "crypto:TRX",  symbol: "TRX",  name: "TRON",      assetClass: .crypto, providerID: "tron"),
        Instrument(id: "crypto:AVAX", symbol: "AVAX", name: "Avalanche", assetClass: .crypto, providerID: "avalanche-2"),
        Instrument(id: "crypto:LINK", symbol: "LINK", name: "Chainlink", assetClass: .crypto, providerID: "chainlink"),
    ]

    // MARK: - VN Equity (HOSE)

    private static let vnPresets: [Instrument] = [
        Instrument(id: "vnEquity:FPT", symbol: "FPT", name: "FPT Corp",         assetClass: .vnEquity, providerID: "FPT"),
        Instrument(id: "vnEquity:VCB", symbol: "VCB", name: "Vietcombank",       assetClass: .vnEquity, providerID: "VCB"),
        Instrument(id: "vnEquity:HPG", symbol: "HPG", name: "Hoa Phat Group",    assetClass: .vnEquity, providerID: "HPG"),
        Instrument(id: "vnEquity:VNM", symbol: "VNM", name: "Vinamilk",          assetClass: .vnEquity, providerID: "VNM"),
        Instrument(id: "vnEquity:MWG", symbol: "MWG", name: "Mobile World",      assetClass: .vnEquity, providerID: "MWG"),
        Instrument(id: "vnEquity:MSN", symbol: "MSN", name: "Masan Group",       assetClass: .vnEquity, providerID: "MSN"),
        Instrument(id: "vnEquity:VIC", symbol: "VIC", name: "Vingroup",          assetClass: .vnEquity, providerID: "VIC"),
        Instrument(id: "vnEquity:VHM", symbol: "VHM", name: "Vinhomes",          assetClass: .vnEquity, providerID: "VHM"),
        Instrument(id: "vnEquity:TCB", symbol: "TCB", name: "Techcombank",       assetClass: .vnEquity, providerID: "TCB"),
        Instrument(id: "vnEquity:ACB", symbol: "ACB", name: "ACB Bank",          assetClass: .vnEquity, providerID: "ACB"),
    ]

    // MARK: - International Equity

    private static let intlPresets: [Instrument] = [
        Instrument(id: "intlEquity:AAPL",  symbol: "AAPL",  name: "Apple",            assetClass: .intlEquity, providerID: "AAPL"),
        Instrument(id: "intlEquity:MSFT",  symbol: "MSFT",  name: "Microsoft",        assetClass: .intlEquity, providerID: "MSFT"),
        Instrument(id: "intlEquity:GOOGL", symbol: "GOOGL", name: "Alphabet",         assetClass: .intlEquity, providerID: "GOOGL"),
        Instrument(id: "intlEquity:AMZN",  symbol: "AMZN",  name: "Amazon",           assetClass: .intlEquity, providerID: "AMZN"),
        Instrument(id: "intlEquity:NVDA",  symbol: "NVDA",  name: "NVIDIA",           assetClass: .intlEquity, providerID: "NVDA"),
        Instrument(id: "intlEquity:META",  symbol: "META",  name: "Meta Platforms",   assetClass: .intlEquity, providerID: "META"),
        Instrument(id: "intlEquity:TSLA",  symbol: "TSLA",  name: "Tesla",            assetClass: .intlEquity, providerID: "TSLA"),
        Instrument(id: "intlEquity:NFLX",  symbol: "NFLX",  name: "Netflix",          assetClass: .intlEquity, providerID: "NFLX"),
        Instrument(id: "intlEquity:AMD",   symbol: "AMD",   name: "AMD",              assetClass: .intlEquity, providerID: "AMD"),
        Instrument(id: "intlEquity:INTC",  symbol: "INTC",  name: "Intel",            assetClass: .intlEquity, providerID: "INTC"),
    ]
}
