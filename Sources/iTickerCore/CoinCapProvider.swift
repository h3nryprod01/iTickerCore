import Foundation

// NOTE: CoinCap uses asset IDs that are assumed to equal the CoinGecko providerID
// (e.g. "bitcoin", "ethereum"). If the CoinGecko providerID diverges from CoinCap's
// asset ID, callers should supply a separate providerID mapping.

// MARK: - CoinCap Decodables

private struct CoinCapAssetResponse: Decodable {
    let data: CoinCapAsset
}

private struct CoinCapAsset: Decodable {
    let id: String
    let symbol: String
    let name: String
    let priceUsd: String?
    let changePercent24Hr: String?
}

private struct CoinCapHistoryResponse: Decodable {
    let data: [CoinCapHistoryPoint]
}

private struct CoinCapHistoryPoint: Decodable {
    let priceUsd: String
    let time: Double            // milliseconds since epoch
}

// MARK: - CoinCapProvider

/// Key-less crypto provider backed by CoinCap public REST API.
/// Uses `instrument.providerID` as the CoinCap asset ID.
public struct CoinCapProvider: PriceProvider {
    public let assetClass: AssetClass = .crypto

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.coincap.io/v2")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: Quotes

    public func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        guard !instruments.isEmpty else { return [] }

        var results: [Quote] = []
        for instrument in instruments {
            if let quote = try await fetchAsset(instrument: instrument) {
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
        let assetID = instrument.providerID
        var components = URLComponents(
            url: baseURL.appendingPathComponent("assets/\(assetID)/history"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "d1")
        ]

        let response: CoinCapHistoryResponse = try await fetch(url: components.url!)
        return response.data.compactMap { point in
            guard let price = Double(point.priceUsd) else { return nil }
            return ChartPoint(
                timestamp: Date(timeIntervalSince1970: point.time / 1000),
                close: price
            )
        }
    }

    // MARK: Internal decode seams (for tests)

    /// Decode a CoinCap asset JSON response into a Quote.
    static func decodeAsset(data: Data, instrument: Instrument) throws(ProviderError) -> Quote? {
        let response: CoinCapAssetResponse
        do {
            response = try JSONDecoder().decode(CoinCapAssetResponse.self, from: data)
        } catch {
            throw .decodingError(error)
        }
        return buildQuote(from: response.data, instrument: instrument)
    }

    /// Decode a CoinCap history JSON response into ChartPoints.
    static func decodeHistory(data: Data) throws(ProviderError) -> [ChartPoint] {
        let response: CoinCapHistoryResponse
        do {
            response = try JSONDecoder().decode(CoinCapHistoryResponse.self, from: data)
        } catch {
            throw .decodingError(error)
        }
        return response.data.compactMap { point in
            guard let price = Double(point.priceUsd) else { return nil }
            return ChartPoint(
                timestamp: Date(timeIntervalSince1970: point.time / 1000),
                close: price
            )
        }
    }

    // MARK: Private helpers

    private func fetchAsset(instrument: Instrument) async throws(ProviderError) -> Quote? {
        let assetID = instrument.providerID
        let url = baseURL.appendingPathComponent("assets/\(assetID)")

        let response: CoinCapAssetResponse = try await fetch(url: url)
        return Self.buildQuote(from: response.data, instrument: instrument)
    }

    private static func buildQuote(from asset: CoinCapAsset, instrument: Instrument) -> Quote? {
        guard let priceStr = asset.priceUsd, let price = Double(priceStr) else { return nil }
        let changePct24h = asset.changePercent24Hr.flatMap { Double($0) }
        return Quote(
            instrument: instrument,
            price: price,
            changePct24h: changePct24h,
            currency: "USD"
        )
    }

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
            if http.statusCode == 404 { throw .notFound(url.lastPathComponent) }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }
}
