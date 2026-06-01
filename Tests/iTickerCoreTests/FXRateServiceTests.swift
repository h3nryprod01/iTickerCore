import Testing
import Foundation
@testable import iTickerCore

@Suite("FXRateService Tests")
struct FXRateServiceTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - decodeUsdToVnd seam tests (no network)

    @Test("Success fixture decodes correct VND rate")
    func successFixtureDecodesRate() throws {
        let data = try loadFixture("er_api_usd.json")
        let rate = try FXRateService.decodeUsdToVnd(data)
        #expect(rate == 25_400.0)
    }

    @Test("result != success throws unavailable")
    func resultNotSuccessThrowsUnavailable() throws {
        let json = """
        { "result": "error", "rates": { "VND": 25400.0 } }
        """.data(using: .utf8)!

        do {
            _ = try FXRateService.decodeUsdToVnd(json)
            Issue.record("Expected unavailable error")
        } catch ProviderError.unavailable {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Missing VND key throws unavailable")
    func missingVNDThrowsUnavailable() throws {
        let json = """
        { "result": "success", "rates": { "EUR": 0.92 } }
        """.data(using: .utf8)!

        do {
            _ = try FXRateService.decodeUsdToVnd(json)
            Issue.record("Expected unavailable error")
        } catch ProviderError.unavailable {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Malformed JSON throws decodingError")
    func malformedJSONThrowsDecodingError() throws {
        let json = "not json at all".data(using: .utf8)!

        do {
            _ = try FXRateService.decodeUsdToVnd(json)
            Issue.record("Expected decodingError")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("VND rate of zero throws decodingError")
    func zeroRateThrowsDecodingError() throws {
        let json = """
        { "result": "success", "rates": { "VND": 0.0 } }
        """.data(using: .utf8)!

        do {
            _ = try FXRateService.decodeUsdToVnd(json)
            Issue.record("Expected decodingError for zero rate")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Negative VND rate throws decodingError")
    func negativeRateThrowsDecodingError() throws {
        let json = """
        { "result": "success", "rates": { "VND": -100.0 } }
        """.data(using: .utf8)!

        do {
            _ = try FXRateService.decodeUsdToVnd(json)
            Issue.record("Expected decodingError for negative rate")
        } catch ProviderError.decodingError {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Network-level tests using StubURLProtocol

    @Test("HTTP 429 throws rateLimited")
    func http429ThrowsRateLimited() async throws {
        let session = URLSession.stubbed(["v6/latest/USD": (Data(), 429)])
        let service = FXRateService(session: session, baseURL: URL(string: "https://fake.er-api.test")!)

        do {
            _ = try await service.usdToVnd()
            Issue.record("Expected rateLimited error")
        } catch ProviderError.rateLimited {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("HTTP 500 throws invalidResponse")
    func http500ThrowsInvalidResponse() async throws {
        let session = URLSession.stubbed(["v6/latest/USD": (Data(), 500)])
        let service = FXRateService(session: session, baseURL: URL(string: "https://fake.er-api.test")!)

        do {
            _ = try await service.usdToVnd()
            Issue.record("Expected invalidResponse error")
        } catch ProviderError.invalidResponse(let code) {
            #expect(code == 500)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Successful network response returns VND rate")
    func successfulNetworkResponseReturnsRate() async throws {
        let data = try loadFixture("er_api_usd.json")
        let session = URLSession.stubbed(["v6/latest/USD": (data, 200)])
        let service = FXRateService(session: session, baseURL: URL(string: "https://fake.er-api.test")!)

        let rate = try await service.usdToVnd()
        #expect(rate == 25_400.0)
    }
}
