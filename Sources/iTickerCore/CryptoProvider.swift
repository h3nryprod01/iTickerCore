import Foundation

// MARK: - CoinGecko Decodables

private struct CGSimplePriceResponse: Decodable {
    // Keys are coin IDs; values are currency maps
    // e.g. { "bitcoin": { "usd": 60000, "usd_24h_change": 1.2 } }
    // Decoded manually because keys are dynamic.
    let prices: [String: CGCoinPrice]

    struct CGCoinPrice: Decodable {
        let usd: Double
        let usd24hChange: Double?

        enum CodingKeys: String, CodingKey {
            case usd
            case usd24hChange = "usd_24h_change"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        var result = [String: CGCoinPrice]()
        for key in container.allKeys {
            result[key.stringValue] = try container.decode(CGCoinPrice.self, forKey: key)
        }
        self.prices = result
    }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private struct CGMarketItem: Decodable {
    let id: String
    let symbol: String
    let name: String
    let currentPrice: Double?
    let priceChangePercentage24h: Double?
    let priceChange24h: Double?
    let totalVolume: Double?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case priceChange24h = "price_change_24h"
        case totalVolume = "total_volume"
    }
}

// MARK: - CryptoProvider

public struct CryptoProvider: PriceProvider {
    public let assetClass: AssetClass = .crypto

    private let session: URLSession
    private let apiKey: String?
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://api.coingecko.com/api/v3")!
    ) {
        self.session = session
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    // MARK: Quotes

    public func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        guard !instruments.isEmpty else { return [] }

        // Build a map from providerID -> requested Instrument for re-stamping
        let instrumentByProviderID: [String: Instrument] = instruments.reduce(into: [:]) { dict, inst in
            dict[inst.providerID] = inst
        }

        let ids = instruments.map(\.providerID).joined(separator: ",")
        var components = URLComponents(url: baseURL.appendingPathComponent("coins/markets"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "ids", value: ids),
            URLQueryItem(name: "price_change_percentage", value: "24h"),
            URLQueryItem(name: "per_page", value: "250"),
        ]
        if let key = apiKey {
            queryItems.append(URLQueryItem(name: "x_cg_demo_api_key", value: key))
        }
        components.queryItems = queryItems

        let url = components.url!
        let items: [CGMarketItem] = try await fetch(url: url)

        let now = Date.now
        return items.compactMap { item in
            guard let price = item.currentPrice else { return nil }
            // Stamp with the exact requested Instrument (keyed by providerID)
            guard let instrument = instrumentByProviderID[item.id] else { return nil }
            return Quote(
                instrument: instrument,
                price: price,
                change24h: item.priceChange24h,
                changePct24h: item.priceChangePercentage24h,
                volume24h: item.totalVolume,
                fetchedAt: now,
                currency: "USD"
            )
        }
    }

    // MARK: Chart

    public func chart(
        for instrument: Instrument,
        interval: ChartInterval
    ) async throws(ProviderError) -> [ChartPoint] {
        let providerID = instrument.providerID
        let days: String
        switch interval {
        case .day: days = "1"
        case .week: days = "7"
        case .month: days = "30"
        case .threeMonths: days = "90"
        case .year: days = "365"
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("coins/\(providerID)/market_chart"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: days),
        ]
        if let key = apiKey {
            queryItems.append(URLQueryItem(name: "x_cg_demo_api_key", value: key))
        }
        components.queryItems = queryItems

        let raw: CGMarketChart = try await fetch(url: components.url!)

        return raw.prices.map { pair in
            let ts = Date(timeIntervalSince1970: pair[0] / 1000)
            return ChartPoint(timestamp: ts, close: pair[1])
        }
    }

    // MARK: Helpers

    private func fetch<T: Decodable>(url: URL) async throws(ProviderError) -> T {
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
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }
}

// MARK: - CG market chart response

private struct CGMarketChart: Decodable {
    let prices: [[Double]]       // [[timestamp_ms, price], ...]
}
