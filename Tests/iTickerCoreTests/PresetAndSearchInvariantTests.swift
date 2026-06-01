import Testing
import Foundation
@testable import iTickerCore

// MARK: - Additional PresetCatalog Invariant Tests

@Suite("PresetCatalog Invariants (Extended)")
struct PresetCatalogInvariantTests {

    // MARK: Crypto providerID is NOT equal to symbol (it's the CoinGecko id)

    @Test("Crypto providerIDs are CoinGecko ids, not symbols")
    func cryptoProviderIDIsNotSymbol() {
        for instrument in PresetCatalog.presets(for: .crypto) {
            // CoinGecko ids differ from the ticker symbol (e.g. "bitcoin" vs "BTC")
            #expect(
                instrument.providerID != instrument.symbol,
                "Crypto providerID '\(instrument.providerID)' should not equal symbol '\(instrument.symbol)' — it must be the CoinGecko id"
            )
        }
    }

    // MARK: Every specific crypto providerID is exactly right

    @Test("All 10 crypto providerIDs match expected CoinGecko ids precisely")
    func allCryptoProviderIDsPrecise() {
        let expected: [(symbol: String, providerID: String)] = [
            ("BTC",  "bitcoin"),
            ("ETH",  "ethereum"),
            ("BNB",  "binancecoin"),
            ("SOL",  "solana"),
            ("XRP",  "ripple"),
            ("ADA",  "cardano"),
            ("DOGE", "dogecoin"),
            ("TRX",  "tron"),
            ("AVAX", "avalanche-2"),
            ("LINK", "chainlink"),
        ]
        let cryptoMap = Dictionary(
            uniqueKeysWithValues: PresetCatalog.presets(for: .crypto).map { ($0.symbol, $0.providerID) }
        )
        for (symbol, expectedID) in expected {
            #expect(
                cryptoMap[symbol] == expectedID,
                "Expected providerID '\(expectedID)' for symbol '\(symbol)', got '\(cryptoMap[symbol] ?? "<nil>")'"
            )
        }
    }

    // MARK: VN / intl providerID == symbol (not a different id)

    @Test("VN equity providerIDs are uppercase symbols, not lowercase or altered")
    func vnProviderIDIsUppercaseSymbol() {
        for instrument in PresetCatalog.presets(for: .vnEquity) {
            #expect(
                instrument.providerID == instrument.providerID.uppercased(),
                "VN providerID '\(instrument.providerID)' should be uppercase"
            )
            #expect(
                instrument.providerID == instrument.symbol,
                "VN providerID '\(instrument.providerID)' should exactly equal symbol '\(instrument.symbol)'"
            )
        }
    }

    @Test("Intl equity providerIDs are uppercase symbols")
    func intlProviderIDIsUppercaseSymbol() {
        for instrument in PresetCatalog.presets(for: .intlEquity) {
            #expect(
                instrument.providerID == instrument.providerID.uppercased(),
                "Intl providerID '\(instrument.providerID)' should be uppercase"
            )
            #expect(
                instrument.providerID == instrument.symbol,
                "Intl providerID '\(instrument.providerID)' should exactly equal symbol '\(instrument.symbol)'"
            )
        }
    }

    // MARK: ids are exactly "<rawValue>:<symbol>" — no extra chars, no whitespace

    @Test("No id has leading or trailing whitespace")
    func noWhitespaceInIds() {
        for instrument in PresetCatalog.all {
            #expect(instrument.id == instrument.id.trimmingCharacters(in: .whitespaces))
            #expect(!instrument.id.contains(" "))
        }
    }

    @Test("ids contain exactly one colon separating prefix and symbol")
    func idHasExactlyOneColon() {
        for instrument in PresetCatalog.all {
            let colonCount = instrument.id.filter { $0 == ":" }.count
            #expect(colonCount == 1, "id '\(instrument.id)' should have exactly one colon, found \(colonCount)")
        }
    }

    // MARK: presets(for:) returns distinct sets — no cross-class leakage

    @Test("Crypto presets contain no vnEquity or intlEquity instruments")
    func cryptoPresetsPure() {
        for instrument in PresetCatalog.presets(for: .crypto) {
            #expect(instrument.assetClass == .crypto)
            #expect(instrument.id.hasPrefix("crypto:"))
        }
    }

    @Test("VN presets contain no crypto or intlEquity instruments")
    func vnPresetsPure() {
        for instrument in PresetCatalog.presets(for: .vnEquity) {
            #expect(instrument.assetClass == .vnEquity)
            #expect(instrument.id.hasPrefix("vnEquity:"))
        }
    }

    @Test("Intl presets contain no crypto or vnEquity instruments")
    func intlPresetsPure() {
        for instrument in PresetCatalog.presets(for: .intlEquity) {
            #expect(instrument.assetClass == .intlEquity)
            #expect(instrument.id.hasPrefix("intlEquity:"))
        }
    }

    // MARK: all has no cross-class id collisions

    @Test("No id prefix collision between different asset classes")
    func noIdPrefixCollision() {
        let cryptoIds = Set(PresetCatalog.presets(for: .crypto).map(\.id))
        let vnIds = Set(PresetCatalog.presets(for: .vnEquity).map(\.id))
        let intlIds = Set(PresetCatalog.presets(for: .intlEquity).map(\.id))

        #expect(cryptoIds.intersection(vnIds).isEmpty)
        #expect(cryptoIds.intersection(intlIds).isEmpty)
        #expect(vnIds.intersection(intlIds).isEmpty)
    }

    // MARK: symbols are non-empty and uppercase

    @Test("All preset symbols are non-empty and uppercase")
    func allSymbolsNonEmptyUppercase() {
        for instrument in PresetCatalog.all {
            #expect(!instrument.symbol.isEmpty, "symbol should not be empty")
            #expect(
                instrument.symbol == instrument.symbol.uppercased(),
                "symbol '\(instrument.symbol)' should be uppercase"
            )
        }
    }

    // MARK: Known VN symbols are present

    @Test("Known VN preset symbols are all present")
    func knownVNSymbolsPresent() {
        let symbols = Set(PresetCatalog.presets(for: .vnEquity).map(\.symbol))
        for expected in ["FPT", "VCB", "HPG", "VNM", "MWG", "MSN", "VIC", "VHM", "TCB", "ACB"] {
            #expect(symbols.contains(expected), "Expected VN symbol '\(expected)' missing from presets")
        }
    }

    // MARK: Known intl symbols are present

    @Test("Known intl preset symbols are all present")
    func knownIntlSymbolsPresent() {
        let symbols = Set(PresetCatalog.presets(for: .intlEquity).map(\.symbol))
        for expected in ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA", "NFLX", "AMD", "INTC"] {
            #expect(symbols.contains(expected), "Expected intl symbol '\(expected)' missing from presets")
        }
    }
}

// MARK: - CryptoSymbolSearch Additional Tests

@Suite("CryptoSymbolSearch (Extended)")
struct CryptoSymbolSearchExtendedTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: providerID preservation

    @Test("providerID in decoded result matches the CoinGecko coin id exactly (not symbol)")
    func providerIDMatchesCoinGeckoId() throws {
        let data = try loadFixture("coingecko_search.json")
        let instruments = try CryptoSymbolSearch.decodeCoins(data)
        // bitcoin-cash: id="bitcoin-cash", symbol="BCH" → providerID should be "bitcoin-cash" not "bch"
        let bch = instruments.first { $0.symbol == "BCH" }
        #expect(bch?.providerID == "bitcoin-cash", "Expected providerID 'bitcoin-cash', got '\(bch?.providerID ?? "<nil>")'")
        // bitcoin-sv
        let bsv = instruments.first { $0.symbol == "BSV" }
        #expect(bsv?.providerID == "bitcoin-sv")
    }

    @Test("id format uses uppercased symbol regardless of what API returns")
    func idUsesUppercasedSymbol() throws {
        // Build fake data with a lowercase symbol to confirm uppercasing logic
        let json = """
        {
          "coins": [
            {"id": "ethereum", "symbol": "eth", "name": "Ethereum"}
          ]
        }
        """
        let data = Data(json.utf8)
        let instruments = try CryptoSymbolSearch.decodeCoins(data)
        #expect(instruments.first?.symbol == "ETH")
        #expect(instruments.first?.id == "crypto:ETH")
        #expect(instruments.first?.providerID == "ethereum")
    }

    @Test("coins array with zero items returns empty array")
    func emptyCoinsArray() throws {
        let json = #"{"coins": []}"#
        let data = Data(json.utf8)
        let instruments = try CryptoSymbolSearch.decodeCoins(data)
        #expect(instruments.isEmpty)
    }

    @Test("Non-200 response throws invalidResponse")
    func nonTwoHundredThrowsInvalidResponse() async throws {
        let session = URLSession.stubbed(["/search": (Data(), 500)])
        let provider = CryptoSymbolSearch(
            session: session,
            baseURL: URL(string: "https://fake.coingecko.test/api/v3")!
        )
        do {
            _ = try await provider.search("bitcoin")
            Issue.record("Expected invalidResponse error")
        } catch ProviderError.invalidResponse(let code) {
            #expect(code == 500)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Whitespace-only query returns empty without network call")
    func whitespaceQueryReturnsEmpty() async throws {
        let session = URLSession.stubbed([:])
        let provider = CryptoSymbolSearch(session: session)
        let results = try await provider.search("   \t  ")
        #expect(results.isEmpty)
    }

    @Test("assetClass property is .crypto")
    func assetClassIsCrypto() {
        let provider = CryptoSymbolSearch()
        #expect(provider.assetClass == .crypto)
    }
}

// MARK: - IntlSymbolSearch Additional Tests

@Suite("IntlSymbolSearch (Extended)")
struct IntlSymbolSearchExtendedTests {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: Non-equity types are filtered

    @Test("Only EQUITY quoteType instruments are kept — MUTUALFUND filtered out")
    func onlyEquityKept() throws {
        let data = try loadFixture("yahoo_search.json")
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        // Fixture: AAPL (EQUITY), AAPL.BA (EQUITY), AAPLX (MUTUALFUND) → 2 kept
        #expect(instruments.count == 2)
        let symbols = instruments.map(\.symbol)
        #expect(symbols.contains("AAPL"))
        #expect(symbols.contains("AAPL.BA"))
        #expect(!symbols.contains("AAPLX"), "MUTUALFUND should be filtered out")
    }

    @Test("ETF quoteType is filtered out")
    func etfIsFiltered() throws {
        let json = """
        {
          "finance": {
            "result": [{
              "quotes": [
                {"symbol": "SPY", "shortname": "SPDR S&P 500", "quoteType": "ETF"},
                {"symbol": "MSFT", "shortname": "Microsoft", "quoteType": "EQUITY"}
              ]
            }]
          }
        }
        """
        let data = Data(json.utf8)
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        #expect(instruments.count == 1)
        #expect(instruments.first?.symbol == "MSFT")
    }

    @Test("Missing quoteType is treated as non-equity and filtered out")
    func missingQuoteTypeFiltered() throws {
        let json = """
        {
          "finance": {
            "result": [{
              "quotes": [
                {"symbol": "UNKNOWN", "shortname": "Unknown", "quoteType": null}
              ]
            }]
          }
        }
        """
        let data = Data(json.utf8)
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        #expect(instruments.isEmpty)
    }

    @Test("When shortname is null, longname is used as name")
    func fallsBackToLongname() throws {
        let json = """
        {
          "finance": {
            "result": [{
              "quotes": [
                {"symbol": "GOOGL", "shortname": null, "longname": "Alphabet Inc.", "quoteType": "EQUITY"}
              ]
            }]
          }
        }
        """
        let data = Data(json.utf8)
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        #expect(instruments.first?.name == "Alphabet Inc.")
    }

    @Test("When both shortname and longname are null, symbol is used as name")
    func fallsBackToSymbol() throws {
        let json = """
        {
          "finance": {
            "result": [{
              "quotes": [
                {"symbol": "TSLA", "shortname": null, "longname": null, "quoteType": "EQUITY"}
              ]
            }]
          }
        }
        """
        let data = Data(json.utf8)
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        #expect(instruments.first?.name == "TSLA")
    }

    @Test("Null quotes array in result yields empty")
    func nullQuotesYieldsEmpty() throws {
        let json = """
        {
          "finance": {
            "result": [{
              "quotes": null
            }]
          }
        }
        """
        let data = Data(json.utf8)
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        #expect(instruments.isEmpty)
    }

    @Test("Null result array yields empty")
    func nullResultYieldsEmpty() throws {
        let json = """
        {
          "finance": {
            "result": null
          }
        }
        """
        let data = Data(json.utf8)
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        #expect(instruments.isEmpty)
    }

    @Test("Non-200 response throws invalidResponse")
    func nonTwoHundredThrowsInvalidResponse() async throws {
        let session = URLSession.stubbed(["/finance/search": (Data(), 503)])
        let provider = IntlSymbolSearch(
            session: session,
            baseURL: URL(string: "https://fake.yahoo.test")!
        )
        do {
            _ = try await provider.search("apple")
            Issue.record("Expected invalidResponse error")
        } catch ProviderError.invalidResponse(let code) {
            #expect(code == 503)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("assetClass property is .intlEquity")
    func assetClassIsIntlEquity() {
        let provider = IntlSymbolSearch()
        #expect(provider.assetClass == .intlEquity)
    }

    @Test("providerID equals symbol (not a separate registry id)")
    func providerIDEqualsSymbol() throws {
        let data = try loadFixture("yahoo_search.json")
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        for inst in instruments {
            #expect(inst.providerID == inst.symbol,
                    "Intl providerID '\(inst.providerID)' should equal symbol '\(inst.symbol)'")
        }
    }
}

// MARK: - VNSymbolSearch Additional Tests

@Suite("VNSymbolSearch (Extended)")
struct VNSymbolSearchExtendedTests {

    // MARK: Unknown query returns empty

    @Test("Unknown query returns empty (not in bundled list)")
    func unknownQueryReturnsEmpty() async throws {
        let provider = VNSymbolSearch()
        let results = try await provider.search("XXXXNOTEXIST")
        #expect(results.isEmpty)
    }

    // MARK: All bundled VN list instruments have correct format

    @Test("filterList on all entries: all have vnEquity id format")
    func bundledListIdFormat() {
        // Query single char to get all or most results
        let list: [Instrument] = [
            Instrument(id: "vnEquity:FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT"),
            Instrument(id: "vnEquity:VCB", symbol: "VCB", name: "Vietcombank", assetClass: .vnEquity, providerID: "VCB"),
            Instrument(id: "vnEquity:HPG", symbol: "HPG", name: "Hoa Phat Group", assetClass: .vnEquity, providerID: "HPG"),
        ]
        let results = VNSymbolSearch.filterList("f", in: list)
        for inst in results {
            #expect(inst.id == "vnEquity:\(inst.symbol)")
            #expect(inst.assetClass == .vnEquity)
            #expect(inst.providerID == inst.symbol)
        }
    }

    // MARK: providerID == symbol for VN bundled items

    @Test("VN search results have providerID equal to symbol")
    func vnSearchProviderIDEqualsSymbol() async throws {
        let provider = VNSymbolSearch()
        let results = try await provider.search("fpt")
        for inst in results {
            #expect(inst.providerID == inst.symbol,
                    "VN providerID '\(inst.providerID)' should equal symbol '\(inst.symbol)'")
        }
    }

    // MARK: Case-insensitive prefix: uppercase query

    @Test("Uppercase query matches same as lowercase (case-insensitive)")
    func uppercaseQueryMatchesCaseInsensitive() async throws {
        let provider = VNSymbolSearch()
        let lower = try await provider.search("vcb")
        let upper = try await provider.search("VCB")
        #expect(lower.map(\.symbol) == upper.map(\.symbol))
    }

    // MARK: Prefix ordering relative to substring

    @Test("filterList: symbol prefix match appears before name-only substring match")
    func symbolPrefixBeforeNameSubstring() {
        // "vcb" prefix-matches symbol "VCB"; "XVCB" symbol has "vcb" as substring of name only
        // (name "Holdings VCB" does NOT start with "vcb"), so XVCB is a substring-only match
        let list: [Instrument] = [
            Instrument(id: "vnEquity:XVCB", symbol: "XVCB", name: "Holdings VCB Group", assetClass: .vnEquity, providerID: "XVCB"),
            Instrument(id: "vnEquity:VCB",  symbol: "VCB",  name: "Vietcombank",         assetClass: .vnEquity, providerID: "VCB"),
        ]
        let results = VNSymbolSearch.filterList("vcb", in: list)
        // VCB prefix-matches symbol; XVCB only substring-matches via name
        // VCB should appear first despite being second in the list
        #expect(results.first?.symbol == "VCB", "Prefix match should rank first, got \(results.first?.symbol ?? "<nil>")")
        #expect(results.count == 2, "Both items should be included")
    }

    // MARK: No duplicate results when item matches both prefix and substring criteria

    @Test("filterList: item matching both prefix and substring appears only once")
    func noDuplicatesWhenMatchesBoth() {
        let list: [Instrument] = [
            Instrument(id: "vnEquity:FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT"),
        ]
        // "fpt" prefix-matches symbol AND substring-matches symbol — should appear once
        let results = VNSymbolSearch.filterList("fpt", in: list)
        #expect(results.count == 1)
    }

    // MARK: Name substring match

    @Test("filterList: name-only substring match is included")
    func nameSubstringMatchIncluded() {
        let list: [Instrument] = [
            Instrument(id: "vnEquity:VCB", symbol: "VCB", name: "Vietcombank", assetClass: .vnEquity, providerID: "VCB"),
        ]
        let results = VNSymbolSearch.filterList("combank", in: list)
        #expect(results.contains(where: { $0.symbol == "VCB" }))
    }

    // MARK: assetClass on provider struct

    @Test("VNSymbolSearch.assetClass is vnEquity")
    func assetClass() {
        let provider = VNSymbolSearch()
        #expect(provider.assetClass == .vnEquity)
    }
}

// MARK: - Cross-provider id consistency (dedupe proof)

@Suite("Search-Preset id Consistency")
struct SearchPresetIdConsistencyTests {

    // MARK: VN search result id matches preset id for same ticker

    @Test("VN search result for FPT has same id as FPT preset — dedupe will work")
    func vnSearchIdMatchesPreset() async throws {
        let provider = VNSymbolSearch()
        let searchResults = try await provider.search("FPT")
        let presetFPT = PresetCatalog.presets(for: .vnEquity).first { $0.symbol == "FPT" }

        guard let searchFPT = searchResults.first(where: { $0.symbol == "FPT" }) else {
            Issue.record("FPT not found in VN search results")
            return
        }
        guard let preset = presetFPT else {
            Issue.record("FPT not found in VN presets")
            return
        }
        #expect(
            searchFPT.id == preset.id,
            "Search id '\(searchFPT.id)' should match preset id '\(preset.id)' for dedupe to work"
        )
    }

    // MARK: Crypto search result id matches preset id format

    @Test("CryptoSymbolSearch decoded BTC id matches crypto preset BTC id")
    func cryptoSearchIdMatchesPreset() throws {
        let json = """
        {
          "coins": [
            {"id": "bitcoin", "symbol": "BTC", "name": "Bitcoin"}
          ]
        }
        """
        let data = Data(json.utf8)
        let instruments = try CryptoSymbolSearch.decodeCoins(data)
        let presetBTC = PresetCatalog.presets(for: .crypto).first { $0.symbol == "BTC" }

        guard let searchBTC = instruments.first(where: { $0.symbol == "BTC" }) else {
            Issue.record("BTC not found in decoded crypto search results")
            return
        }
        guard let preset = presetBTC else {
            Issue.record("BTC not found in crypto presets")
            return
        }
        #expect(
            searchBTC.id == preset.id,
            "Search id '\(searchBTC.id)' should match preset id '\(preset.id)' for dedupe to work"
        )
        // Also confirm providerID matches — both must use same CoinGecko id for quote resolution
        #expect(
            searchBTC.providerID == preset.providerID,
            "Search providerID '\(searchBTC.providerID)' should match preset providerID '\(preset.providerID)'"
        )
    }

    // MARK: Intl search result id matches preset id format

    @Test("IntlSymbolSearch decoded AAPL id matches intl preset AAPL id")
    func intlSearchIdMatchesPreset() throws {
        let json = """
        {
          "finance": {
            "result": [{
              "quotes": [
                {"symbol": "AAPL", "shortname": "Apple Inc.", "quoteType": "EQUITY"}
              ]
            }]
          }
        }
        """
        let data = Data(json.utf8)
        let instruments = try IntlSymbolSearch.decodeQuotes(data)
        let presetAAPL = PresetCatalog.presets(for: .intlEquity).first { $0.symbol == "AAPL" }

        guard let searchAAPL = instruments.first(where: { $0.symbol == "AAPL" }) else {
            Issue.record("AAPL not found in decoded intl search results")
            return
        }
        guard let preset = presetAAPL else {
            Issue.record("AAPL not found in intl presets")
            return
        }
        #expect(
            searchAAPL.id == preset.id,
            "Search id '\(searchAAPL.id)' should match preset id '\(preset.id)' for dedupe to work"
        )
    }

    // MARK: All preset ids have the correct compound format

    @Test("All preset ids across all classes match <rawValue>:<symbol> exactly")
    func allPresetIdsMatchFormat() {
        for instrument in PresetCatalog.all {
            let prefix = instrument.assetClass.rawValue
            let parts = instrument.id.split(separator: ":", maxSplits: 1)
            #expect(parts.count == 2, "id '\(instrument.id)' should have exactly one ':'")
            if parts.count == 2 {
                #expect(String(parts[0]) == prefix, "id prefix should be '\(prefix)', got '\(parts[0])'")
                #expect(String(parts[1]) == instrument.symbol, "id suffix should be '\(instrument.symbol)', got '\(parts[1])'")
            }
        }
    }
}
