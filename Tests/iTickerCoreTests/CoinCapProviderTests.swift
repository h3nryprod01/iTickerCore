import Testing
import Foundation
@testable import iTickerCore

@Suite("CoinCapProvider Tests")
struct CoinCapProviderTests {

    private let btc = Instrument(
        id: "bitcoin", symbol: "BTC", name: "Bitcoin",
        assetClass: .crypto, providerID: "bitcoin"
    )

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Quotes

    @Test("Decodes asset fixture into Quote with price and changePct24h")
    func decodesAsset() async throws {
        let data = try loadFixture("coincap_asset.json")
        let session = URLSession.stubbed(["assets/bitcoin": (data, 200)])

        let provider = CoinCapProvider(
            session: session,
            baseURL: URL(string: "https://fake.coincap.test/v2")!
        )

        let quotes = try await provider.quotes(for: [btc])
        #expect(quotes.count == 1)

        let quote = quotes[0]
        #expect(quote.instrument.id == "bitcoin")
        #expect(abs(quote.price - 61500.4321) < 0.0001)
        let changePct = try #require(quote.changePct24h)
        #expect(abs(changePct - 1.8765) < 0.001)
    }

    @Test("Decode seam: decodeAsset produces correct Quote from fixture")
    func decodeSeamAsset() throws {
        let data = try loadFixture("coincap_asset.json")
        let quote = try CoinCapProvider.decodeAsset(data: data, instrument: btc)
        let q = try #require(quote)
        #expect(abs(q.price - 61500.4321) < 0.0001)
        #expect(q.instrument.id == "bitcoin")
    }

    @Test("Returns empty for empty input")
    func emptyInput() async throws {
        let session = URLSession.stubbed([:])
        let provider = CoinCapProvider(session: session)
        let quotes = try await provider.quotes(for: [])
        #expect(quotes.isEmpty)
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimitedOn429() async throws {
        let session = URLSession.stubbed(["assets/bitcoin": (Data(), 429)])
        let provider = CoinCapProvider(
            session: session,
            baseURL: URL(string: "https://fake.coincap.test/v2")!
        )

        do {
            _ = try await provider.quotes(for: [btc])
            Issue.record("Expected rateLimited error")
        } catch ProviderError.rateLimited {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws notFound on 404")
    func throwsNotFoundOn404() async throws {
        let session = URLSession.stubbed(["assets/bitcoin": (Data(), 404)])
        let provider = CoinCapProvider(
            session: session,
            baseURL: URL(string: "https://fake.coincap.test/v2")!
        )

        do {
            _ = try await provider.quotes(for: [btc])
            Issue.record("Expected notFound error")
        } catch ProviderError.notFound {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws decodingError on malformed JSON")
    func throwsDecodingErrorOnBadJSON() async throws {
        let badData = Data("not json".utf8)
        let session = URLSession.stubbed(["assets/bitcoin": (badData, 200)])
        let provider = CoinCapProvider(
            session: session,
            baseURL: URL(string: "https://fake.coincap.test/v2")!
        )

        do {
            _ = try await provider.quotes(for: [btc])
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Chart

    @Test("Decodes history fixture into ChartPoints")
    func decodesHistory() async throws {
        let data = try loadFixture("coincap_history.json")
        let session = URLSession.stubbed(["assets/bitcoin/history": (data, 200)])

        let provider = CoinCapProvider(
            session: session,
            baseURL: URL(string: "https://fake.coincap.test/v2")!
        )

        let points = try await provider.chart(for: btc, interval: .month)
        #expect(points.count == 3)
        #expect(abs(points[0].close - 58000.0) < 0.01)
        #expect(abs(points[2].close - 61500.4321) < 0.001)
    }

    @Test("Decode seam: decodeHistory produces correct ChartPoints from fixture")
    func decodeSeamHistory() throws {
        let data = try loadFixture("coincap_history.json")
        let points = try CoinCapProvider.decodeHistory(data: data)
        #expect(points.count == 3)
        #expect(abs(points[1].close - 59500.0) < 0.01)
    }

    @Test("Throws decodingError on malformed history JSON")
    func throwsDecodingErrorOnBadHistoryJSON() async throws {
        let badData = Data("{\"data\": \"not an array\"}".utf8)
        let session = URLSession.stubbed(["assets/bitcoin/history": (badData, 200)])
        let provider = CoinCapProvider(
            session: session,
            baseURL: URL(string: "https://fake.coincap.test/v2")!
        )

        do {
            _ = try await provider.chart(for: btc, interval: .month)
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
