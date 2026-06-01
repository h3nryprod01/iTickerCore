import Foundation
import CryptoKit

// MARK: - BinanceBalance

/// A single asset balance returned by the Binance /api/v3/account endpoint.
public struct BinanceBalance: Sendable, Equatable {
    public let asset: String
    public let free: Double
    public let locked: Double

    public var total: Double { free + locked }

    public init(asset: String, free: Double, locked: Double) {
        self.asset = asset
        self.free = free
        self.locked = locked
    }
}

// MARK: - BinanceAccountError

/// Errors produced by BinanceAccountService.
/// INVARIANT: `userMessage` MUST NEVER contain the API secret or signature.
public enum BinanceAccountError: Error, Sendable {
    /// API key format is invalid (Binance code -2014).
    case invalidKeyFormat
    /// API key is invalid, lacks read permission, or IP is not whitelisted (Binance code -2015).
    case permissionOrIP
    /// Timestamp out of the server's recvWindow (Binance code -1021). Device clock may be skewed.
    case badTimestamp
    /// Binance is not accessible from this region or IP (HTTP 403/451).
    case geoBlocked
    /// Rate limited (HTTP 429).
    case rateLimited
    /// A network-layer error (DNS, TLS, timeout, etc.).
    case network(Error)
    /// The response body could not be decoded.
    case decoding(Error)
    /// An HTTP error not covered by specific cases; carries the status code.
    case http(Int)
    /// Any other Binance application-level error code.
    case binanceError(code: Int, message: String)

    /// Human-friendly description. Never contains the secret or signature.
    public var userMessage: String {
        switch self {
        case .invalidKeyFormat:
            return "API key format is invalid. Please check your key and try again."
        case .permissionOrIP:
            return "API key is invalid, lacks read permission, or your IP is not whitelisted. Please create a read-only key and check any IP restrictions."
        case .badTimestamp:
            return "Request timestamp was outside the allowed window. Your device clock may be out of sync — please check your system time and try again."
        case .geoBlocked:
            return "Binance is not available from your region or IP address. A VPN or proxy may be required."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .network:
            return "A network error occurred. Please check your connection and try again."
        case .decoding:
            return "The server response could not be understood. Please try again."
        case .http(let code):
            return "Unexpected server response (HTTP \(code)). Please try again."
        case .binanceError(_, let message):
            // Use Binance's own message (it does not contain the secret)
            return "Binance error: \(message)"
        }
    }
}

// MARK: - Internal decodables (private to this file)

private struct BinanceAccountResponse: Decodable {
    let balances: [RawBalance]

    struct RawBalance: Decodable {
        let asset: String
        let free: String
        let locked: String
    }
}

private struct BinanceErrorBody: Decodable {
    let code: Int
    let msg: String
}

private struct BinanceServerTime: Decodable {
    let serverTime: Int64
}

// MARK: - BinanceAccountService

/// Read-only Binance account client.
///
/// Usage:
/// ```swift
/// let service = BinanceAccountService()
/// let balances = try await service.account(apiKey: key, secret: secret)
/// ```
///
/// The secret is used ONLY to compute the HMAC-SHA256 signature locally.
/// It is NEVER sent over the network, NEVER included in errors, and NEVER logged.
public struct BinanceAccountService: Sendable {

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.binance.com/api/v3")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: - Public API

    /// Fetch all balances for the account.
    /// - Parameters:
    ///   - apiKey: Binance read-only API key (sent in `X-MBX-APIKEY` header).
    ///   - secret: Binance API secret (used ONLY for local HMAC signing; never transmitted).
    ///   - recvWindow: Allowed timestamp skew in milliseconds (default 60000).
    public func account(
        apiKey: String,
        secret: String,
        recvWindow: Int = 60000
    ) async throws(BinanceAccountError) -> [BinanceBalance] {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        return try await fetchAccount(
            apiKey: apiKey,
            secret: secret,
            timestamp: timestamp,
            recvWindow: recvWindow
        )
    }

    // MARK: - Optional server time correction

    /// Fetch Binance server time (milliseconds since epoch).
    /// Use this to correct device clock skew when a -1021 error occurs.
    public func serverTime() async throws(BinanceAccountError) -> Int64 {
        let url = baseURL.appendingPathComponent("time")
        let data = try await fetchData(url: url, apiKey: nil)
        let body: BinanceServerTime
        do {
            body = try JSONDecoder().decode(BinanceServerTime.self, from: data)
        } catch {
            throw .decoding(error)
        }
        return body.serverTime
    }

    // MARK: - Signing seam (internal, testable)

    /// Compute HMAC-SHA256(query, secret) and return the lowercase hex string.
    ///
    /// Test vector (from Binance API docs):
    /// - secret: "NhqPtmdSJYdKjVHjA7PZj4Mge3R5YNiP1e3UZjInClVN65XAbvqqM6A7H5fATj0j"
    /// - query:  "symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"
    /// - expected: "c8db56825ae71d6d79447849e617115f4a920fa2acdcab2b053c4b2838bd6b71"
    static func sign(query: String, secret: String) -> String {
        let keyData = Data(secret.utf8)
        let messageData = Data(query.utf8)
        let hmac = HMAC<SHA256>.authenticationCode(for: messageData, using: SymmetricKey(data: keyData))
        return hmac.map { String(format: "%02x", $0) }.joined()
    }

    /// Decode a Binance /api/v3/account response body into [BinanceBalance].
    /// Balances with unparseable amounts default to 0.0.
    static func decodeBalances(_ data: Data) throws(BinanceAccountError) -> [BinanceBalance] {
        let response: BinanceAccountResponse
        do {
            response = try JSONDecoder().decode(BinanceAccountResponse.self, from: data)
        } catch {
            throw .decoding(error)
        }
        return response.balances.map { raw in
            BinanceBalance(
                asset: raw.asset,
                free: Double(raw.free) ?? 0.0,
                locked: Double(raw.locked) ?? 0.0
            )
        }
    }

    // MARK: - Private

    private func fetchAccount(
        apiKey: String,
        secret: String,
        timestamp: Int64,
        recvWindow: Int
    ) async throws(BinanceAccountError) -> [BinanceBalance] {
        let query = "timestamp=\(timestamp)&recvWindow=\(recvWindow)"
        let signature = Self.sign(query: query, secret: secret)
        let fullQuery = "\(query)&signature=\(signature)"

        var components = URLComponents(
            url: baseURL.appendingPathComponent("account"),
            resolvingAgainstBaseURL: false
        )!
        components.query = fullQuery
        guard let url = components.url else {
            throw .http(0)
        }

        let data = try await fetchData(url: url, apiKey: apiKey)
        return try Self.decodeBalances(data)
    }

    /// Fetch raw data, mapping HTTP errors (including Binance JSON error bodies) to BinanceAccountError.
    private func fetchData(url: URL, apiKey: String?) async throws(BinanceAccountError) -> Data {
        var request = URLRequest(url: url)
        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw .http(0)
        }

        switch http.statusCode {
        case 200:
            return data
        case 403, 451:
            throw .geoBlocked
        case 429:
            throw .rateLimited
        default:
            // Try to parse a Binance error body
            if let errorBody = try? JSONDecoder().decode(BinanceErrorBody.self, from: data) {
                throw mapBinanceErrorCode(errorBody.code, message: errorBody.msg)
            }
            throw .http(http.statusCode)
        }
    }

    private func mapBinanceErrorCode(_ code: Int, message: String) -> BinanceAccountError {
        switch code {
        case -2014: return .invalidKeyFormat
        case -2015: return .permissionOrIP
        case -1021: return .badTimestamp
        default:    return .binanceError(code: code, message: message)
        }
    }
}
