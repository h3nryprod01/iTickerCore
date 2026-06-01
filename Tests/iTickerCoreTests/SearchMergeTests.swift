import Testing
import Foundation
@testable import iTickerCore

// MARK: - Fixtures

private func crypto(_ symbol: String, name: String = "") -> Instrument {
    Instrument(
        id: "crypto:\(symbol)",
        symbol: symbol,
        name: name.isEmpty ? "\(symbol) Token" : name,
        assetClass: .crypto,
        providerID: symbol.lowercased()
    )
}

private func vn(_ symbol: String, name: String = "") -> Instrument {
    Instrument(
        id: "vnEquity:\(symbol)",
        symbol: symbol,
        name: name.isEmpty ? "\(symbol) Corp" : name,
        assetClass: .vnEquity,
        providerID: symbol
    )
}

private func intl(_ symbol: String, name: String = "") -> Instrument {
    Instrument(
        id: "intlEquity:\(symbol)",
        symbol: symbol,
        name: name.isEmpty ? "\(symbol) Inc" : name,
        assetClass: .intlEquity,
        providerID: symbol
    )
}

// MARK: - SearchMergeTests

@Suite("SearchMerge Tests")
struct SearchMergeTests {

    // MARK: - mergeSearchResults: dedupe

    @Test("Deduplication by id — duplicate from incoming is dropped")
    func dedupeByID() {
        let btc = crypto("BTC", name: "Bitcoin")
        let existing = [btc]
        let incoming = [btc, crypto("ETH", name: "Ethereum")]

        let merged = SearchMerge.mergeSearchResults(existing: existing, incoming: incoming, query: "btc")

        // BTC should appear exactly once
        let btcCount = merged.filter { $0.id == "crypto:BTC" }.count
        #expect(btcCount == 1)
        // ETH should also be present
        #expect(merged.contains(where: { $0.id == "crypto:ETH" }))
    }

    @Test("Deduplication preserves existing order for the first occurrence")
    func dedupeKeepsFirstOccurrence() {
        let btcA = Instrument(id: "crypto:BTC", symbol: "BTC", name: "Bitcoin A", assetClass: .crypto, providerID: "bitcoin")
        let btcB = Instrument(id: "crypto:BTC", symbol: "BTC", name: "Bitcoin B", assetClass: .crypto, providerID: "bitcoin2")
        let existing = [btcA]
        let incoming = [btcB]

        let merged = SearchMerge.mergeSearchResults(existing: existing, incoming: incoming, query: "btc")
        // The existing item (name "Bitcoin A") should win
        #expect(merged.first(where: { $0.id == "crypto:BTC" })?.name == "Bitcoin A")
    }

    @Test("Empty existing + non-empty incoming returns incoming ranked")
    func emptyExisting() {
        let instruments = [crypto("ETH"), crypto("BTC")]
        let merged = SearchMerge.mergeSearchResults(existing: [], incoming: instruments, query: "BTC")

        // BTC should be ranked before ETH (exact symbol match)
        #expect(merged.first?.symbol == "BTC")
    }

    @Test("Non-empty existing + empty incoming returns existing ranked")
    func emptyIncoming() {
        let instruments = [crypto("ETH"), crypto("BTC")]
        let merged = SearchMerge.mergeSearchResults(existing: instruments, incoming: [], query: "btc")
        #expect(merged.first?.symbol == "BTC")
    }

    @Test("Both empty returns empty")
    func bothEmpty() {
        let merged = SearchMerge.mergeSearchResults(existing: [], incoming: [], query: "btc")
        #expect(merged.isEmpty)
    }

    // MARK: - rankSearchResults: ranking tiers

    @Test("Exact symbol match ranked before symbol prefix match")
    func exactSymbolBeforePrefix() {
        let exact  = crypto("BTC", name: "Bitcoin")
        let prefix = crypto("BTCN", name: "Bitcoin Nano")
        let result = SearchMerge.rankSearchResults([prefix, exact], query: "BTC")
        #expect(result.first?.symbol == "BTC")
    }

    @Test("Symbol prefix ranked before name prefix")
    func symbolPrefixBeforeNamePrefix() {
        let namePfx   = crypto("XYZ", name: "BTCoin Protocol")
        let symbolPfx = crypto("BTCX", name: "Some Token")
        let result = SearchMerge.rankSearchResults([namePfx, symbolPfx], query: "btc")
        #expect(result.first?.symbol == "BTCX")
    }

    @Test("Name prefix ranked before symbol substring")
    func namePrefixBeforeSymbolSubstring() {
        let symSub  = crypto("XBTCZ", name: "ZZZ Token")  // substring in symbol
        let namePfx = crypto("AAA",  name: "Bitcoin Cash") // name prefix
        let result = SearchMerge.rankSearchResults([symSub, namePfx], query: "bitcoin")
        #expect(result.first?.symbol == "AAA")
    }

    @Test("Symbol substring ranked before name substring")
    func symbolSubstringBeforeNameSubstring() {
        let nameSub = crypto("XYZ", name: "Some BTC Exchange")    // substring in name
        let symSub  = crypto("XBTCZ", name: "ZZZ")                // substring in symbol
        let result = SearchMerge.rankSearchResults([nameSub, symSub], query: "btc")
        #expect(result.first?.symbol == "XBTCZ")
    }

    @Test("Case-insensitive ranking")
    func caseInsensitiveRanking() {
        let lower = crypto("btc", name: "bitcoin")
        let upper = crypto("BTC", name: "Bitcoin")
        // Both should be considered exact matches; relative order preserved
        let result = SearchMerge.rankSearchResults([lower, upper], query: "BTC")
        #expect(!result.isEmpty)
        // first item has same symbol
        let first = result.first!
        #expect(first.symbol.lowercased() == "btc")
    }

    // MARK: - Mixed asset classes

    @Test("Mixed asset classes — best match wins regardless of class")
    func mixedAssetClasses() {
        let vnExact   = vn("BTC", name: "BTC Vietnam")      // exact symbol match
        let cryptoSub = crypto("XBTCZ", name: "ZZZ Token") // substring
        let intlPfx   = intl("BTCA", name: "BTC America")  // symbol prefix

        let result = SearchMerge.rankSearchResults([cryptoSub, intlPfx, vnExact], query: "btc")
        // Exact symbol match should be first
        #expect(result.first?.id == "vnEquity:BTC")
        // Symbol prefix second
        #expect(result[1].id == "intlEquity:BTCA")
        // Substring last
        #expect(result[2].id == "crypto:XBTCZ")
    }

    @Test("Merge across 3 providers dedupes and ranks")
    func mergeThreeProviders() {
        let fptCrypto = crypto("FPT", name: "FPT Token")
        let fptVN     = vn("FPT", name: "FPT Corp")       // same symbol, different id
        let fptIntl   = intl("FPTX", name: "FPT Exchange")

        // Simulate: existing = cryptoProvider results, incoming = vnProvider results
        var accumulated = SearchMerge.mergeSearchResults(existing: [fptCrypto], incoming: [fptVN], query: "FPT")
        // Then fold in intl
        accumulated = SearchMerge.mergeSearchResults(existing: accumulated, incoming: [fptIntl], query: "FPT")

        // All three are distinct ids — all should be present
        #expect(accumulated.count == 3)
        let ids = Set(accumulated.map(\.id))
        #expect(ids.contains("crypto:FPT"))
        #expect(ids.contains("vnEquity:FPT"))
        #expect(ids.contains("intlEquity:FPTX"))
    }

    // MARK: - Stable order within tier

    @Test("Stable order within the same tier preserves input order")
    func stableWithinTier() {
        // Both have symbol prefix match (no exact match)
        let a = crypto("AAAA", name: "A Token")
        let b = crypto("AABB", name: "B Token")
        let c = crypto("AACC", name: "C Token")

        let result = SearchMerge.rankSearchResults([a, b, c], query: "aa")
        // All three prefix-match "aa" → should preserve input order
        let symbols = result.map(\.symbol)
        #expect(symbols == ["AAAA", "AABB", "AACC"])
    }

    // MARK: - Empty query

    @Test("Empty query returns list unchanged")
    func emptyQueryReturnsUnchanged() {
        let instruments = [crypto("BTC"), crypto("ETH"), vn("FPT")]
        let result = SearchMerge.rankSearchResults(instruments, query: "")
        #expect(result.map(\.id) == instruments.map(\.id))
    }

    @Test("Whitespace-only query returns list unchanged")
    func whitespaceQueryReturnsUnchanged() {
        let instruments = [crypto("BTC"), vn("FPT")]
        let result = SearchMerge.rankSearchResults(instruments, query: "   ")
        #expect(result.map(\.id) == instruments.map(\.id))
    }

    // MARK: - Case-insensitive exact match (lowercase query vs uppercase symbol)

    @Test("Lowercase query exactly matches uppercase symbol")
    func lowercaseQueryMatchesUppercaseSymbol() {
        let btc  = crypto("BTC", name: "Bitcoin")
        let btcx = crypto("BTCX", name: "Bitcoin Extended")
        // query "btc" (lowercase) should see "BTC" as exact match and "BTCX" as prefix
        let result = SearchMerge.rankSearchResults([btcx, btc], query: "btc")
        #expect(result.first?.symbol == "BTC", "Lowercase query must exact-match uppercase symbol")
        #expect(result[1].symbol == "BTCX")
    }

    @Test("Uppercase query exactly matches lowercase symbol")
    func uppercaseQueryMatchesLowercaseSymbol() {
        let btc  = crypto("btc", name: "bitcoin")
        let btcx = crypto("btcx", name: "bitcoin extended")
        // query "BTC" should exact-match "btc"
        let result = SearchMerge.rankSearchResults([btcx, btc], query: "BTC")
        #expect(result.first?.symbol == "btc", "Uppercase query must exact-match lowercase symbol")
    }

    // MARK: - Symbol-prefix beats name-prefix (explicit construction)

    @Test("Symbol-prefix beats name-prefix — name starts with query, symbol starts with query")
    func symbolPrefixOutranksNamePrefixExplicit() {
        // "eth" query: ETHCoin has symbol starting with "eth" → prefixSymbol
        // AnotherCoin has name "ethereum classic" starting with "eth" → prefixName
        let symbolPrefixCoin = crypto("ETHX", name: "Wrapped Ether")
        let namePrefixCoin   = crypto("WETH", name: "Ethereum Classic")
        let result = SearchMerge.rankSearchResults([namePrefixCoin, symbolPrefixCoin], query: "eth")
        #expect(result.first?.symbol == "ETHX",
                "Symbol-prefix (ETHX) must rank above name-prefix (WETH/Ethereum Classic)")
        #expect(result[1].symbol == "WETH")
    }

    // MARK: - Dedupe from 2 sources + kept item ranks correctly

    @Test("Dedupe across 2 sources: kept item (first occurrence) lands in correct tier")
    func dedupeAndKeptItemRanksCorrectly() {
        // Simulate: source 1 returns BTC (the existing one) — a full-name match (name substring)
        // Source 2 returns the same id BTC but also ETH (exact symbol match for "eth" query).
        // We're checking with query "btc" that deduping keeps the first BTC AND ranks it correctly.
        let btcFromSource1 = Instrument(
            id: "crypto:BTC", symbol: "BTC", name: "Bitcoin from source1",
            assetClass: .crypto, providerID: "bitcoin-s1"
        )
        let btcFromSource2 = Instrument(
            id: "crypto:BTC", symbol: "BTC", name: "Bitcoin from source2",
            assetClass: .crypto, providerID: "bitcoin-s2"
        )
        let eth = crypto("ETH", name: "Ethereum")

        // Merge: existing = [btcFromSource1], incoming = [btcFromSource2, eth]
        let result = SearchMerge.mergeSearchResults(
            existing: [btcFromSource1],
            incoming: [btcFromSource2, eth],
            query: "btc"
        )

        // BTC appears once (deduped)
        let btcResults = result.filter { $0.id == "crypto:BTC" }
        #expect(btcResults.count == 1, "BTC must appear exactly once after dedupe")

        // The kept BTC is from source1
        #expect(btcResults.first?.providerID == "bitcoin-s1",
                "First occurrence (source1) must be kept, not source2")

        // BTC (exact match for "btc") ranks before ETH (no match)
        let btcIndex = result.firstIndex(where: { $0.id == "crypto:BTC" })!
        let ethIndex = result.firstIndex(where: { $0.symbol == "ETH" })!
        #expect(btcIndex < ethIndex, "BTC (exact symbol match) must rank before ETH (no match for 'btc')")
    }

    // MARK: - Stable within tier across multiple tier levels

    @Test("Stable sort: equal-tier items preserve original order across 3 prefix-symbol items")
    func stableWithinTierThreePrefixItems() {
        // All three have symbol-prefix match for "aa"
        let x = crypto("AAXXX", name: "X Token")
        let y = crypto("AAYYY", name: "Y Token")
        let z = crypto("AAZZZ", name: "Z Token")

        // Pass in reverse order to verify stable sort restores the original relative order
        let result = SearchMerge.rankSearchResults([z, y, x], query: "aa")
        // All three are in prefixSymbol tier; original order [z, y, x] must be preserved
        #expect(result.map(\.symbol) == ["AAZZZ", "AAYYY", "AAXXX"],
                "Stable sort must preserve original input order within same tier")
    }

    @Test("Stable sort: deterministic when same-tier instruments come from mergeSearchResults")
    func stableOrderAfterMerge() {
        // Add 3 items one by one via merge and confirm final order is deterministic
        let a = crypto("AAPL", name: "Apple Inc")
        let b = crypto("AABB", name: "BB Corp")
        let c = crypto("AACC", name: "CC Corp")
        // All prefix "aa"

        var result = SearchMerge.mergeSearchResults(existing: [a], incoming: [b], query: "aa")
        result = SearchMerge.mergeSearchResults(existing: result, incoming: [c], query: "aa")

        // a was first, then b was appended, then c was appended
        let symbols = result.map(\.symbol)
        #expect(symbols == ["AAPL", "AABB", "AACC"],
                "Stable merge must preserve insertion order within same tier")
    }

    // MARK: - Non-matching items ranked after all real matches

    @Test("Non-matching items rank after name-substring matches")
    func nonMatchingItemsRankedAfterRealMatches() {
        let noMatch   = crypto("XYZ", name: "Totally Unrelated")
        let nameSub   = crypto("QRS", name: "The Best Coin BTC exchange")
        // query: "btc" — nameSub has "btc" in name (substring), noMatch has nothing
        let result = SearchMerge.rankSearchResults([noMatch, nameSub], query: "btc")
        // nameSub must rank before noMatch
        #expect(result.first?.symbol == "QRS",
                "Name-substring match must rank before non-matching item")
        #expect(result.last?.symbol == "XYZ",
                "Non-matching item must be last, not interleaved with real matches")
    }
}
