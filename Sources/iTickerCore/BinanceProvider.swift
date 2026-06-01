import Foundation

// MARK: - Binance Decodables

private struct BinanceTicker24hr: Decodable {
    let symbol: String
    let lastPrice: String
    let priceChange: String
    let priceChangePercent: String
    let quoteVolume: String
}

private struct BinanceKline: Decodable {
    // Binance klines are arrays: [openTime, open, high, low, close, volume, ...]
    // We decode as [AnyCodable] and extract by index.
    let openTime: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        openTime = try container.decode(Double.self)
        open     = Double(try container.decode(String.self)) ?? 0
        high     = Double(try container.decode(String.self)) ?? 0
        low      = Double(try container.decode(String.self)) ?? 0
        close    = Double(try container.decode(String.self)) ?? 0
        volume   = Double(try container.decode(String.self)) ?? 0
        // Remaining fields ignored
    }
}

// MARK: - BinanceProvider

/// Key-less crypto provider backed by Binance public REST API.
/// Symbols are mapped: `instrument.symbol.uppercased() + "USDT"` (e.g. BTC -> BTCUSDT).
public struct BinanceProvider: PriceProvider {
    public let assetClass: AssetClass = .crypto

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.binance.com/api/v3")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: Quotes

    public func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        guard !instruments.isEmpty else { return [] }

        var results: [Quote] = []
        for instrument in instruments {
            if let quote = try await fetchTicker(instrument: instrument) {
                results.append(quote)
            }
        }
        return results
    }

    // MARK: Chart

    public func chart(
        for instrument: Instrument,
        interval: ChartInterval
    ) async throws(ProviderError) -> [ChartPoint] {
        let (binanceInterval, limit) = binanceParams(for: interval)
        let binanceSymbol = Self.binanceSymbol(for: instrument.symbol)

        var components = URLComponents(
            url: baseURL.appendingPathComponent("klines"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: binanceSymbol),
            URLQueryItem(name: "interval", value: binanceInterval),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        let klines: [BinanceKline] = try await fetch(url: components.url!)
        return klines.map { kline in
            ChartPoint(
                timestamp: Date(timeIntervalSince1970: kline.openTime / 1000),
                close: kline.close,
                open: kline.open,
                high: kline.high,
                low: kline.low,
                volume: kline.volume
            )
        }
    }

    // MARK: Internal decode seam (for tests)

    /// Decode a 24hr ticker JSON Data into a Quote for the given Instrument.
    static func decodeTicker(data: Data, instrument: Instrument) throws(ProviderError) -> Quote? {
        let ticker: BinanceTicker24hr
        do {
            ticker = try JSONDecoder().decode(BinanceTicker24hr.self, from: data)
        } catch {
            throw .decodingError(error)
        }
        return buildQuote(from: ticker, instrument: instrument)
    }

    /// Decode klines JSON Data into ChartPoints.
    static func decodeKlines(data: Data) throws(ProviderError) -> [ChartPoint] {
        let klines: [BinanceKline]
        do {
            klines = try JSONDecoder().decode([BinanceKline].self, from: data)
        } catch {
            throw .decodingError(error)
        }
        return klines.map { kline in
            ChartPoint(
                timestamp: Date(timeIntervalSince1970: kline.openTime / 1000),
                close: kline.close,
                open: kline.open,
                high: kline.high,
                low: kline.low,
                volume: kline.volume
            )
        }
    }

    // MARK: Private helpers

    private func fetchTicker(instrument: Instrument) async throws(ProviderError) -> Quote? {
        let binanceSymbol = Self.binanceSymbol(for: instrument.symbol)
        var components = URLComponents(
            url: baseURL.appendingPathComponent("ticker/24hr"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: binanceSymbol)
        ]

        let data: Data = try await fetchData(url: components.url!)
        let ticker: BinanceTicker24hr
        do {
            ticker = try JSONDecoder().decode(BinanceTicker24hr.self, from: data)
        } catch {
            throw .decodingError(error)
        }
        return Self.buildQuote(from: ticker, instrument: instrument)
    }

    private static func buildQuote(from ticker: BinanceTicker24hr, instrument: Instrument) -> Quote? {
        guard let price = Double(ticker.lastPrice) else { return nil }
        let change24h = Double(ticker.priceChange)
        let changePct24h = Double(ticker.priceChangePercent)
        let volume24h = Double(ticker.quoteVolume)
        return Quote(
            instrument: instrument,
            price: price,
            change24h: change24h,
            changePct24h: changePct24h,
            volume24h: volume24h,
            currency: "USD"
        )
    }

    private func fetch<T: Decodable>(url: URL) async throws(ProviderError) -> T {
        let data: Data = try await fetchData(url: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }

    private func fetchData(url: URL) async throws(ProviderError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw .networkError(error)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw .rateLimited }
            if http.statusCode == 400 || http.statusCode == 404 { throw .notFound(url.absoluteString) }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }
        return data
    }

    /// Map ChartInterval to Binance interval string and candle limit.
    private func binanceParams(for interval: ChartInterval) -> (interval: String, limit: Int) {
        switch interval {
        case .day:         return ("1m",  1440)
        case .week:        return ("15m", 672)
        case .month:       return ("1h",  720)
        case .threeMonths: return ("4h",  546)
        case .year:        return ("1d",  365)
        }
    }

    /// Map symbol to Binance trading pair: uppercased + "USDT" suffix.
    static func binanceSymbol(for symbol: String) -> String {
        "\(symbol.uppercased())USDT"
    }
}
