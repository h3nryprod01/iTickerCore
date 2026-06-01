import Foundation

// MARK: - Yahoo Finance Decodables

private struct YFChartResponse: Decodable {
    let chart: YFChartWrapper

    struct YFChartWrapper: Decodable {
        let result: [YFChartResult]?
        let error: YFError?
    }

    struct YFChartResult: Decodable {
        let meta: YFMeta
        let timestamp: [Double]?
        let indicators: YFIndicators?
    }

    struct YFMeta: Decodable {
        let symbol: String
        let regularMarketPrice: Double?
        let previousClose: Double?
        let shortName: String?
        let longName: String?
        /// ISO 4217 currency code from Yahoo, e.g. "USD", "EUR", "GBP", "JPY".
        /// Falls back to "USD" when absent from the response.
        let currency: String?
    }

    struct YFIndicators: Decodable {
        let quote: [YFQuote]?
    }

    struct YFQuote: Decodable {
        let open: [Double?]?
        let high: [Double?]?
        let low: [Double?]?
        let close: [Double?]?
        let volume: [Double?]?
    }

    struct YFError: Decodable {
        let code: String?
        let description: String?
    }
}

// MARK: - IntlStockProvider

public actor IntlStockProvider: PriceProvider {
    public nonisolated let assetClass: AssetClass = .intlEquity

    private let session: URLSession
    private let baseURL: URL
    private var cachedCrumb: String?
    private var crumbFetchedAt: Date?

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://query1.finance.yahoo.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: Quotes

    public func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        guard !instruments.isEmpty else { return [] }
        var results: [Quote] = []
        for instrument in instruments {
            if let quote = try await fetchQuote(instrument: instrument) {
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
        let (range, resolution) = yfParams(for: interval)
        let result = try await fetchChart(symbol: instrument.symbol, range: range, interval: resolution)
        return result
    }

    // MARK: Private helpers

    private func fetchQuote(instrument: Instrument) async throws(ProviderError) -> Quote? {
        let symbol = instrument.symbol
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v8/finance/chart/\(symbol)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "interval", value: "1m"),
            URLQueryItem(name: "includePrePost", value: "false"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw .rateLimited }
            if http.statusCode == 404 { throw .notFound(symbol) }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }

        let yfResponse: YFChartResponse
        do {
            yfResponse = try JSONDecoder().decode(YFChartResponse.self, from: data)
        } catch {
            throw .decodingError(error)
        }

        if let err = yfResponse.chart.error, let code = err.code {
            throw .unavailable(code)
        }

        guard let result = yfResponse.chart.result?.first else { return nil }
        let meta = result.meta

        // Use regularMarketPrice as current price (not the last intraday close)
        guard let price = meta.regularMarketPrice else { return nil }
        let previousClose = meta.previousClose
        let change24h: Double? = previousClose.map { price - $0 }
        let changePct24h: Double? = previousClose.flatMap { prev in
            guard prev != 0 else { return nil }
            return (price - prev) / prev * 100
        }

        return Quote(
            instrument: instrument,
            price: price,
            change24h: change24h,
            changePct24h: changePct24h,
            volume24h: nil,
            currency: meta.currency ?? "USD"
        )
    }

    private func fetchChart(symbol: String, range: String, interval: String) async throws(ProviderError) -> [ChartPoint] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v8/finance/chart/\(symbol)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "range", value: range),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "includePrePost", value: "false"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw .rateLimited }
            if http.statusCode == 404 { throw .notFound(symbol) }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }

        let yfResponse: YFChartResponse
        do {
            yfResponse = try JSONDecoder().decode(YFChartResponse.self, from: data)
        } catch {
            throw .decodingError(error)
        }

        if let err = yfResponse.chart.error, let code = err.code {
            throw .unavailable(code)
        }

        guard let result = yfResponse.chart.result?.first else { return [] }
        guard let timestamps = result.timestamp, !timestamps.isEmpty else { return [] }
        let closes = result.indicators?.quote?.first?.close

        var points: [ChartPoint] = []
        for (i, ts) in timestamps.enumerated() {
            let close = closes?[safe: i] ?? nil
            guard let c = close else { continue }
            let point = ChartPoint(
                timestamp: Date(timeIntervalSince1970: ts),
                close: c,
                open: result.indicators?.quote?.first?.open?[safe: i] ?? nil,
                high: result.indicators?.quote?.first?.high?[safe: i] ?? nil,
                low: result.indicators?.quote?.first?.low?[safe: i] ?? nil,
                volume: result.indicators?.quote?.first?.volume?[safe: i] ?? nil
            )
            points.append(point)
        }
        return points
    }

    private func yfParams(for interval: ChartInterval) -> (range: String, resolution: String) {
        switch interval {
        case .day: return ("1d", "5m")
        case .week: return ("5d", "15m")
        case .month: return ("1mo", "1d")
        case .threeMonths: return ("3mo", "1d")
        case .year: return ("1y", "1wk")
        }
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
