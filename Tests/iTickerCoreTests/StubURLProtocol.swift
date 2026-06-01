import Foundation

// MARK: - Thread-safe stub registry

/// Maps a session identifier (stored in URLSessionConfiguration.identifier) to stubs.
/// Using a lock makes it safe for parallel test runs.
final class StubRegistry: @unchecked Sendable {
    static let shared = StubRegistry()
    private var store: [String: [String: (data: Data, statusCode: Int)]] = [:]
    private let lock = NSLock()

    func setStubs(_ stubs: [String: (Data, Int)], forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        store[key] = stubs.mapValues { (data: $0.0, statusCode: $0.1) }
    }

    func stubs(forKey key: String) -> [String: (data: Data, statusCode: Int)] {
        lock.lock(); defer { lock.unlock() }
        return store[key] ?? [:]
    }

    func removeStubs(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
}

// MARK: - StubURLProtocol

/// URLProtocol that looks up stubs from StubRegistry using the session identifier.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // The session identifier is set in URLSessionConfiguration.httpAdditionalHeaders["X-Stub-Key"]
        let key = request.value(forHTTPHeaderField: "X-Stub-Key") ?? ""
        let stubs = StubRegistry.shared.stubs(forKey: key)
        let urlString = request.url?.absoluteString ?? ""
        let match = stubs.first(where: { urlString.contains($0.key) })

        if let entry = match?.value {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: entry.statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: entry.data)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let error = NSError(domain: "StubURLProtocol", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No stub for \(urlString)"
            ])
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - URLSession factory

extension URLSession {
    /// Creates a URLSession that uses StubURLProtocol with the given stubs.
    /// Each call gets a unique key so parallel tests don't share state.
    static func stubbed(
        _ stubs: [String: (Data, Int)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> URLSession {
        let key = "\(file):\(line):\(UUID().uuidString)"
        StubRegistry.shared.setStubs(stubs, forKey: key)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Stub-Key": key]
        return URLSession(configuration: config)
    }
}
