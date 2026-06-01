import Foundation

// MARK: - VNDirect Decodables

// NOTE: This endpoint is unofficial (dchart-api.vndirect.com.vn).
// UDF history shape: { "s":"ok"|"no_data"|"error", "t":[unix], "o":[], "h":[], "l":[], "c":[], "v":[] }
private struct VNDirectHistoryResponse: Decodable {
    let s: String          // "ok", "no_data", "error"
    let t: [Double]?       // timestamps
    let o: [Double]?
    let h: [Double]?
    let l: [Double]?
    let c: [Double]?
    let v: [Double]?
}

// MARK: - VNDirectProvider

public struct VNDirectProvider: PriceProvider {
    public let assetClass: AssetClass = .vnEquity

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://dchart-api.vndirect.com.vn")!
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
        let (from, to) = timeRange(for: interval)
        let response = try await fetchHistory(symbol: instrument.symbol, from: from, to: to)
        guard let timestamps = response.t, !timestamps.isEmpty else { return [] }

        var points: [ChartPoint] = []
        for i in timestamps.indices {
            guard let close = response.c?[safe: i] else { continue }
            // Scale OHLC from thousands-VND to full VND. Volume is a share count — do not scale.
            let point = ChartPoint(
                timestamp: Date(timeIntervalSince1970: timestamps[i]),
                close: close * tcbsVNDScale,
                open: response.o?[safe: i].map { $0 * tcbsVNDScale },
                high: response.h?[safe: i].map { $0 * tcbsVNDScale },
                low: response.l?[safe: i].map { $0 * tcbsVNDScale },
                volume: response.v?[safe: i]
            )
            points.append(point)
        }
        return points
    }

    // MARK: Private helpers

    private func fetchQuote(instrument: Instrument) async throws(ProviderError) -> Quote? {
        let ticker = instrument.symbol
        // Fetch last 7 days to derive last close and day-over-day change
        let to = Int(Date.now.timeIntervalSince1970)
        let from = to - 7 * 86400

        let response = try await fetchHistory(symbol: ticker, from: from, to: to)

        guard response.s == "ok" else {
            if response.s == "no_data" { throw .notFound(ticker) }
            throw .unavailable("VNDirect returned status: \(response.s)")
        }

        guard let closes = response.c, closes.count >= 1 else { return nil }
        let lastClose = closes[closes.count - 1]
        let prevClose: Double? = closes.count >= 2 ? closes[closes.count - 2] : nil

        let change24h: Double? = prevClose.map { lastClose - $0 }
        let changePct24h: Double? = prevClose.flatMap { prev in
            guard prev != 0 else { return nil }
            return (lastClose - prev) / prev * 100
        }
        let volume24h: Double? = response.v.flatMap { v in
            v.isEmpty ? nil : v[v.count - 1]
        }

        // VNDirect dchart/history returns prices in THOUSANDS of VND (same convention as TCBS).
        // E.g. FPT ≈ 72.9 from the API → ₫72,900. Multiply by tcbsVNDScale (1000) to get full VND.
        // changePct24h is a ratio — do NOT scale it.
        return Quote(
            instrument: instrument,
            price: lastClose * tcbsVNDScale,
            change24h: change24h.map { $0 * tcbsVNDScale },
            changePct24h: changePct24h,
            volume24h: volume24h,
            currency: "VND"
        )
    }

    private func fetchHistory(symbol: String, from: Int, to: Int) async throws(ProviderError) -> VNDirectHistoryResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("dchart/history"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "resolution", value: "D"),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "from", value: String(from)),
            URLQueryItem(name: "to", value: String(to)),
        ]
        return try await fetch(url: components.url!)
    }

    private func fetch<T: Decodable>(url: URL) async throws(ProviderError) -> T {
        var request = URLRequest(url: url)
        request.setValue("iTicker/1.0", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw .rateLimited }
            if http.statusCode == 404 { throw .notFound(url.lastPathComponent) }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }

    private func timeRange(for interval: ChartInterval) -> (from: Int, to: Int) {
        let to = Int(Date.now.timeIntervalSince1970)
        let days: Int
        switch interval {
        case .day: days = 1
        case .week: days = 7
        case .month: days = 30
        case .threeMonths: days = 90
        case .year: days = 365
        }
        return (to - days * 86400, to)
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
