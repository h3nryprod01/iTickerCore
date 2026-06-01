import Foundation

// MARK: - FXRateService

/// Fetches the USD → VND exchange rate from the open.er-api.com free tier.
/// No API key is required.
///
/// Endpoint: GET https://open.er-api.com/v6/latest/USD
/// Response shape:
///   { "result": "success", "rates": { "VND": 25400.0, ... } }
public struct FXRateService: Sendable {

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://open.er-api.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Fetch the current USD → VND exchange rate.
    /// - Returns: Number of VND per 1 USD (e.g. 25400.0).
    /// - Throws: `ProviderError` on network, HTTP, or decoding failure.
    public func usdToVnd() async throws(ProviderError) -> Double {
        let url = baseURL.appendingPathComponent("v6/latest/USD")
        let request = URLRequest(url: url)

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

        return try Self.decodeUsdToVnd(data)
    }

    // MARK: - Internal decode seam (used directly in tests with fixture data)

    /// Decode the USD → VND rate from raw JSON data.
    /// Exposed as `internal` so tests can call it directly with fixture data,
    /// avoiding any live network dependency.
    static func decodeUsdToVnd(_ data: Data) throws(ProviderError) -> Double {
        let root: ERAPIResponse
        do {
            root = try JSONDecoder().decode(ERAPIResponse.self, from: data)
        } catch {
            throw .decodingError(error)
        }

        guard root.result == "success" else {
            throw .unavailable("result=\(root.result)")
        }

        guard let rate = root.rates["VND"] else {
            throw .unavailable("VND rate missing from response")
        }

        guard rate.isFinite, rate > 0 else {
            throw .decodingError(FXDecodeError.invalidRate(rate))
        }

        return rate
    }
}

// MARK: - Private decodables

private struct ERAPIResponse: Decodable {
    let result: String
    let rates: [String: Double]
}

// MARK: - FXDecodeError

private enum FXDecodeError: Error {
    case invalidRate(Double)
}
