import Testing
import Foundation
@testable import iTickerCore

@Suite("SymbolSearchProvider Tests")
struct SymbolSearchProviderTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - CryptoSymbolSearch

    @Suite("CryptoSymbolSearch")
    struct CryptoSymbolSearchTests {

        private func loadFixture(_ name: String) throws -> Data {
            guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
                throw FixtureError.notFound(name)
            }
            return try Data(contentsOf: url)
        }

        @Test("Decodes coingecko_search fixture into Instruments")
        func decodesFixture() throws {
            let data = try loadFixture("coingecko_search.json")
            let instruments = try CryptoSymbolSearch.decodeCoins(data)
            #expect(instruments.count == 3)

            let btc = instruments.first
            #expect(btc?.symbol == "BTC")
            #expect(btc?.id == "crypto:BTC")
            #expect(btc?.providerID == "bitcoin")
            #expect(btc?.assetClass == .crypto)
            #expect(btc?.name == "Bitcoin")
        }

        @Test("Symbols are uppercased")
        func symbolsUppercased() throws {
            let data = try loadFixture("coingecko_search.json")
            let instruments = try CryptoSymbolSearch.decodeCoins(data)
            for inst in instruments {
                #expect(inst.symbol == inst.symbol.uppercased())
            }
        }

        @Test("id follows crypto:<SYMBOL> format")
        func idFormat() throws {
            let data = try loadFixture("coingecko_search.json")
            let instruments = try CryptoSymbolSearch.decodeCoins(data)
            for inst in instruments {
                #expect(inst.id == "crypto:\(inst.symbol)")
            }
        }

        @Test("Empty query returns empty without network call")
        func emptyQuery() async throws {
            let session = URLSession.stubbed([:])
            let provider = CryptoSymbolSearch(session: session)
            let results = try await provider.search("   ")
            #expect(results.isEmpty)
        }

        @Test("Malformed JSON throws decodingError")
        func malformedJSON() {
            let badData = Data("{ bad json".utf8)
            do {
                _ = try CryptoSymbolSearch.decodeCoins(badData)
                Issue.record("Expected decodingError")
            } catch ProviderError.decodingError {
                // Expected
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("429 response throws rateLimited")
        func rateLimited() async throws {
            let session = URLSession.stubbed(["/search": (Data(), 429)])
            let provider = CryptoSymbolSearch(
                session: session,
                baseURL: URL(string: "https://fake.coingecko.test/api/v3")!
            )
            do {
                _ = try await provider.search("bitcoin")
                Issue.record("Expected rateLimited")
            } catch ProviderError.rateLimited {
                // Expected
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("200 with fixture data via stubbed session returns instruments")
        func stubbedSession() async throws {
            guard let url = Bundle.module.url(forResource: "coingecko_search.json", withExtension: nil, subdirectory: "Fixtures") else {
                Issue.record("Fixture not found")
                return
            }
            let data = try Data(contentsOf: url)
            let session = URLSession.stubbed(["/search": (data, 200)])
            let provider = CryptoSymbolSearch(
                session: session,
                baseURL: URL(string: "https://fake.coingecko.test/api/v3")!
            )
            let results = try await provider.search("bitcoin")
            #expect(results.count == 3)
            #expect(results.first?.providerID == "bitcoin")
        }
    }

    // MARK: - IntlSymbolSearch

    @Suite("IntlSymbolSearch")
    struct IntlSymbolSearchTests {

        private func loadFixture(_ name: String) throws -> Data {
            guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
                throw FixtureError.notFound(name)
            }
            return try Data(contentsOf: url)
        }

        @Test("Decodes yahoo_search fixture, keeps only EQUITY types")
        func decodesFixture() throws {
            let data = try loadFixture("yahoo_search.json")
            let instruments = try IntlSymbolSearch.decodeQuotes(data)
            // Fixture has 3 quotes: 2 EQUITY + 1 MUTUALFUND — should keep only 2 equities
            #expect(instruments.count == 2)

            let aapl = instruments.first
            #expect(aapl?.symbol == "AAPL")
            #expect(aapl?.id == "intlEquity:AAPL")
            #expect(aapl?.providerID == "AAPL")
            #expect(aapl?.assetClass == .intlEquity)
            #expect(aapl?.name == "Apple Inc.")
        }

        @Test("id follows intlEquity:<SYMBOL> format")
        func idFormat() throws {
            let data = try loadFixture("yahoo_search.json")
            let instruments = try IntlSymbolSearch.decodeQuotes(data)
            for inst in instruments {
                #expect(inst.id == "intlEquity:\(inst.symbol)")
            }
        }

        @Test("Empty query returns empty without network call")
        func emptyQuery() async throws {
            let session = URLSession.stubbed([:])
            let provider = IntlSymbolSearch(session: session)
            let results = try await provider.search("")
            #expect(results.isEmpty)
        }

        @Test("Malformed JSON throws decodingError")
        func malformedJSON() {
            let badData = Data("{ bad json".utf8)
            do {
                _ = try IntlSymbolSearch.decodeQuotes(badData)
                Issue.record("Expected decodingError")
            } catch ProviderError.decodingError {
                // Expected
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("429 response throws rateLimited")
        func rateLimited() async throws {
            let session = URLSession.stubbed(["/finance/search": (Data(), 429)])
            let provider = IntlSymbolSearch(
                session: session,
                baseURL: URL(string: "https://fake.yahoo.test")!
            )
            do {
                _ = try await provider.search("apple")
                Issue.record("Expected rateLimited")
            } catch ProviderError.rateLimited {
                // Expected
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("200 with fixture data via stubbed session returns instruments")
        func stubbedSession() async throws {
            guard let url = Bundle.module.url(forResource: "yahoo_search.json", withExtension: nil, subdirectory: "Fixtures") else {
                Issue.record("Fixture not found")
                return
            }
            let data = try Data(contentsOf: url)
            let session = URLSession.stubbed(["/finance/search": (data, 200)])
            let provider = IntlSymbolSearch(
                session: session,
                baseURL: URL(string: "https://fake.yahoo.test")!
            )
            let results = try await provider.search("apple")
            #expect(results.count == 2)
        }
    }

    // MARK: - VNSymbolSearch

    @Suite("VNSymbolSearch")
    struct VNSymbolSearchTests {

        @Test("Empty query returns empty")
        func emptyQuery() async throws {
            let provider = VNSymbolSearch()
            let results = try await provider.search("  ")
            #expect(results.isEmpty)
        }

        @Test("Prefix match on symbol returns result")
        func prefixMatchSymbol() async throws {
            let provider = VNSymbolSearch()
            let results = try await provider.search("FP")
            #expect(results.contains(where: { $0.symbol == "FPT" }))
        }

        @Test("Prefix match is case-insensitive")
        func prefixMatchCaseInsensitive() async throws {
            let provider = VNSymbolSearch()
            let results = try await provider.search("fpt")
            #expect(results.contains(where: { $0.symbol == "FPT" }))
        }

        @Test("Substring match on name returns result")
        func substringMatchName() async throws {
            let provider = VNSymbolSearch()
            let results = try await provider.search("bank")
            #expect(!results.isEmpty)
            let symbols = results.map(\.symbol)
            // Several bank stocks should match
            #expect(symbols.contains("VCB") || symbols.contains("TCB") || symbols.contains("ACB"))
        }

        @Test("No network call — no ProviderError thrown for any query")
        func noNetworkNeeded() async throws {
            let provider = VNSymbolSearch()
            // VNSymbolSearch is offline; any query should succeed without network
            let results = try await provider.search("vcb")
            #expect(results.contains(where: { $0.symbol == "VCB" }))
        }

        @Test("ids follow vnEquity:<SYMBOL> format")
        func idFormat() async throws {
            let provider = VNSymbolSearch()
            let results = try await provider.search("v")
            for inst in results {
                #expect(inst.id == "vnEquity:\(inst.symbol)")
            }
        }

        @Test("assetClass is vnEquity")
        func assetClass() async throws {
            let provider = VNSymbolSearch()
            let results = try await provider.search("vcb")
            for inst in results {
                #expect(inst.assetClass == .vnEquity)
            }
        }

        @Test("filterList prefix matches come before substring-only matches")
        func prefixBeforeSubstring() {
            let list: [Instrument] = [
                Instrument(id: "vnEquity:ABCDEF", symbol: "ABCDEF", name: "ABCDEF Corp", assetClass: .vnEquity, providerID: "ABCDEF"),
                Instrument(id: "vnEquity:XABC", symbol: "XABC", name: "X ABCDEF Holdings", assetClass: .vnEquity, providerID: "XABC"),
            ]
            let results = VNSymbolSearch.filterList("abc", in: list)
            // ABCDEF prefix-matches "abc" first; XABC only substring-matches via name
            #expect(results.first?.symbol == "ABCDEF")
        }
    }
}
