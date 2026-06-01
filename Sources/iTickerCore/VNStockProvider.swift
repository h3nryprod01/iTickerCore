import Foundation

// MARK: - TCBS Decodables

private struct TCBSQuoteResponse: Decodable {
    let data: [TCBSTicker]

    struct TCBSTicker: Decodable {
        let ticker: String
        let lastPrice: Double?
        let priceChange: Double?
        let priceChangeRatio: Double?
        let totalVolume: Double?
    }
}

private struct TCBSBarResponse: Decodable {
    let data: TCBSBarData

    struct TCBSBarData: Decodable {
        let t: [Double]?     // timestamps
        let o: [Double]?
        let h: [Double]?
        let l: [Double]?
        let c: [Double]?
        let v: [Double]?
    }
}

// MARK: - VNStockProvider

/// Scale factor for ALL VN equity providers — TCBS, VNDirect, and SSI all return
/// prices in THOUSANDS of VND (e.g. FPT ≈ 72.9 → ₫72,900).
///
/// Multiply `price` and `change24h` by this constant when building a `Quote`.
/// `changePct24h` (a ratio) and `volume24h` (share count) are NOT scaled.
let tcbsVNDScale: Double = 1000.0

public struct VNStockProvider: PriceProvider {
    public let assetClass: AssetClass = .vnEquity

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        // Corrected host: apipubaws (not apipubaapi).
        // Path prefix: stock-insight/v1/
        baseURL: URL = URL(string: "https://apipubaws.tcbs.com.vn/stock-insight/v1")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: Quotes

    public func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        guard !instruments.isEmpty else { return [] }

        // TCBS supports individual ticker queries; we call them sequentially
        var results: [Quote] = []
        for instrument in instruments {
            if let quote = try await fetchSingle(instrument: instrument) {
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
        let ticker = instrument.symbol
        let resolution: String
        let countBack: Int
        switch interval {
        case .day: resolution = "1"; countBack = 390
        case .week: resolution = "D"; countBack = 5
        case .month: resolution = "D"; countBack = 22
        case .threeMonths: resolution = "D"; countBack = 65
        case .year: resolution = "D"; countBack = 252
        }

        let toTime = Int(Date.now.timeIntervalSince1970)
        let fromTime = toTime - countBack * 86400

        var components = URLComponents(
            url: baseURL.appendingPathComponent("stock/bars-long-term"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "type", value: "stock"),
            URLQueryItem(name: "resolution", value: resolution),
            URLQueryItem(name: "from", value: String(fromTime)),
            URLQueryItem(name: "to", value: String(toTime)),
        ]

        let raw: TCBSBarResponse = try await fetch(url: components.url!)
        let barData = raw.data
        guard let timestamps = barData.t, !timestamps.isEmpty else {
            return []
        }

        var points: [ChartPoint] = []
        for i in timestamps.indices {
            guard let close = barData.c?[safe: i] else { continue }
            // Scale OHLC values from TCBS thousands-VND to full VND.
            // Volume is a share count — do NOT scale it.
            let point = ChartPoint(
                timestamp: Date(timeIntervalSince1970: timestamps[i]),
                close: close * tcbsVNDScale,
                open: barData.o?[safe: i].map { $0 * tcbsVNDScale },
                high: barData.h?[safe: i].map { $0 * tcbsVNDScale },
                low: barData.l?[safe: i].map { $0 * tcbsVNDScale },
                volume: barData.v?[safe: i]
            )
            points.append(point)
        }
        return points
    }

    // MARK: Helpers

    private func fetchSingle(instrument: Instrument) async throws(ProviderError) -> Quote? {
        let ticker = instrument.symbol
        var components = URLComponents(
            url: baseURL.appendingPathComponent("stock/second-tc-price"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "tickers", value: ticker)
        ]

        let raw: TCBSQuoteResponse = try await fetch(url: components.url!)

        guard let item = raw.data.first else { return nil }
        guard let price = item.lastPrice else { return nil }

        // TCBS reports prices in thousands of VND; multiply to get full VND.
        // priceChangeRatio is already a fraction — do NOT scale it.
        return Quote(
            instrument: instrument,
            price: price * tcbsVNDScale,
            change24h: item.priceChange.map { $0 * tcbsVNDScale },
            changePct24h: item.priceChangeRatio.map { $0 * 100 },
            volume24h: item.totalVolume,
            currency: "VND"
        )
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
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
