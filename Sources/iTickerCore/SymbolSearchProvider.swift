import Foundation

// MARK: - SymbolSearchProvider

/// Protocol for searching instrument symbols within a given asset class.
///
/// Implementations:
///   - `CryptoSymbolSearch`: live CoinGecko search endpoint
///   - `IntlSymbolSearch`: live Yahoo Finance search endpoint
///   - `VNSymbolSearch`: offline prefix/substring search over a bundled VN list
///
/// All return `[Instrument]` with ids in `"<assetClassRaw>:<symbol>"` format
/// to stay consistent with the dedupe + menu-bar toggle logic.
public protocol SymbolSearchProvider: Sendable {
    var assetClass: AssetClass { get }

    /// Search for instruments matching `query`. Returns `[]` for empty/whitespace query.
    /// Throws `ProviderError` on network, decode, or rate-limit failures.
    func search(_ query: String) async throws(ProviderError) -> [Instrument]
}

// MARK: - CryptoSymbolSearch

/// Searches CoinGecko `/api/v3/search` for crypto instruments.
///
/// - Rate limits are shared with `CryptoProvider`; the caller should debounce (~300ms).
/// - Returns empty array for blank query; propagates 429 as `.rateLimited`.
public struct CryptoSymbolSearch: SymbolSearchProvider {
    public let assetClass: AssetClass = .crypto

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.coingecko.com/api/v3")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func search(_ query: String) async throws(ProviderError) -> [Instrument] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: trimmed)]
        guard let url = components.url else { return [] }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw .networkError(error)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw .rateLimited }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }
        return try Self.decodeCoins(data)
    }

    /// Internal seam used by unit tests to parse fixture data without a live network call.
    static func decodeCoins(_ data: Data) throws(ProviderError) -> [Instrument] {
        struct CGSearchResponse: Decodable {
            let coins: [CGSearchCoin]
        }
        struct CGSearchCoin: Decodable {
            let id: String
            let symbol: String
            let name: String
        }

        let response: CGSearchResponse
        do {
            response = try JSONDecoder().decode(CGSearchResponse.self, from: data)
        } catch {
            throw .decodingError(error)
        }
        return response.coins.map { coin in
            let sym = coin.symbol.uppercased()
            return Instrument(
                id: "crypto:\(sym)",
                symbol: sym,
                name: coin.name,
                assetClass: .crypto,
                providerID: coin.id
            )
        }
    }
}

// MARK: - IntlSymbolSearch

/// Searches Yahoo Finance `/v1/finance/search` for international equity instruments.
///
/// - Uses the same desktop User-Agent as `IntlStockProvider` to avoid bot detection.
/// - Filters to equity-type results only.
/// - Unofficial endpoint; may rate-limit or break. Propagates 429 as `.rateLimited`.
public struct IntlSymbolSearch: SymbolSearchProvider {
    public let assetClass: AssetClass = .intlEquity

    private let session: URLSession
    private let baseURL: URL

    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://query1.finance.yahoo.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func search(_ query: String) async throws(ProviderError) -> [Instrument] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(url: baseURL.appendingPathComponent("v1/finance/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "quotesCount", value: "10"),
            URLQueryItem(name: "newsCount", value: "0"),
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(Self.desktopUserAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw .rateLimited }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }
        return try Self.decodeQuotes(data)
    }

    /// Internal seam used by unit tests to parse fixture data without a live network call.
    static func decodeQuotes(_ data: Data) throws(ProviderError) -> [Instrument] {
        struct YFSearchResponse: Decodable {
            let finance: YFFinance
            struct YFFinance: Decodable {
                let result: [YFResult]?
                struct YFResult: Decodable {
                    let quotes: [YFQuote]?
                }
            }
        }
        struct YFQuote: Decodable {
            let symbol: String
            let shortname: String?
            let longname: String?
            let quoteType: String?
        }

        let response: YFSearchResponse
        do {
            response = try JSONDecoder().decode(YFSearchResponse.self, from: data)
        } catch {
            throw .decodingError(error)
        }

        let quotes = response.finance.result?.first?.quotes ?? []
        // Keep only equity-like quoteTypes; filter out mutual funds, ETFs etc.
        let equityTypes: Set<String> = ["EQUITY"]
        return quotes
            .filter { equityTypes.contains($0.quoteType ?? "") }
            .map { q in
                let sym = q.symbol
                let name = q.shortname ?? q.longname ?? sym
                return Instrument(
                    id: "intlEquity:\(sym)",
                    symbol: sym,
                    name: name,
                    assetClass: .intlEquity,
                    providerID: sym
                )
            }
    }
}

// MARK: - VNSymbolSearch

/// Offline search over a bundled VN stock list (HOSE/HNX).
///
/// No network calls. Filters by case-insensitive prefix match on symbol/name first,
/// then appends case-insensitive substring matches not already included.
/// Tradeoff: only covers the curated list; new listings won't appear until the list is updated.
public struct VNSymbolSearch: SymbolSearchProvider {
    public let assetClass: AssetClass = .vnEquity

    public init() {}

    public func search(_ query: String) async throws(ProviderError) -> [Instrument] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return Self.filterList(trimmed, in: vnBundledList)
    }

    /// Internal seam: pure filter logic, injectable for tests.
    static func filterList(_ query: String, in list: [Instrument]) -> [Instrument] {
        let q = query.lowercased()
        var seen = Set<String>()
        var results: [Instrument] = []

        // 1. Prefix matches (symbol or name)
        for inst in list {
            if inst.symbol.lowercased().hasPrefix(q) || inst.name.lowercased().hasPrefix(q) {
                if seen.insert(inst.id).inserted {
                    results.append(inst)
                }
            }
        }

        // 2. Substring matches not already in results
        for inst in list {
            if inst.symbol.lowercased().contains(q) || inst.name.lowercased().contains(q) {
                if seen.insert(inst.id).inserted {
                    results.append(inst)
                }
            }
        }
        return results
    }
}

// MARK: - Bundled VN list

/// VN30 + common HOSE/HNX symbols with display names.
/// Static; updated in source, not fetched live.
private let vnBundledList: [Instrument] = {
    let entries: [(String, String)] = [
        // VN preset 10
        ("FPT", "FPT Corp"),
        ("VCB", "Vietcombank"),
        ("HPG", "Hoa Phat Group"),
        ("VNM", "Vinamilk"),
        ("MWG", "Mobile World"),
        ("MSN", "Masan Group"),
        ("VIC", "Vingroup"),
        ("VHM", "Vinhomes"),
        ("TCB", "Techcombank"),
        ("ACB", "ACB Bank"),
        // Additional VN30+ common HOSE/HNX tickers
        ("VPB", "VPBank"),
        ("BID", "BIDV"),
        ("CTG", "Vietinbank"),
        ("GAS", "PetroVietnam Gas"),
        ("VRE", "Vincom Retail"),
        ("PLX", "Petrolimex"),
        ("POW", "PetroVietnam Power"),
        ("SAB", "Sabeco"),
        ("SSI", "SSI Securities"),
        ("STB", "Sacombank"),
        ("VJC", "VietJet Air"),
        ("BVH", "Bao Viet Holdings"),
        ("GVR", "Vietnam Rubber Group"),
        ("PNJ", "PNJ Gold"),
        ("KDH", "Khang Dien House"),
        ("MBB", "Military Bank"),
        ("HDB", "HDBank"),
        ("TPB", "TPBank"),
        ("REE", "REE Corp"),
        ("DGC", "Duc Giang Chemicals"),
    ]
    return entries.map { (symbol, name) in
        Instrument(
            id: "vnEquity:\(symbol)",
            symbol: symbol,
            name: name,
            assetClass: .vnEquity,
            providerID: symbol
        )
    }
}()
