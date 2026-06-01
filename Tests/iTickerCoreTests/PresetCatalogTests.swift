import Testing
import Foundation
@testable import iTickerCore

@Suite("PresetCatalog Tests")
struct PresetCatalogTests {

    @Test("Returns 10 crypto presets")
    func cryptoCount() {
        #expect(PresetCatalog.presets(for: .crypto).count == 10)
    }

    @Test("Returns 10 VN equity presets")
    func vnCount() {
        #expect(PresetCatalog.presets(for: .vnEquity).count == 10)
    }

    @Test("Returns 10 intl equity presets")
    func intlCount() {
        #expect(PresetCatalog.presets(for: .intlEquity).count == 10)
    }

    @Test("All returns 30 presets total")
    func allCount() {
        #expect(PresetCatalog.all.count == 30)
    }

    @Test("Every id follows <assetClassRaw>:<symbol> format")
    func idFormat() {
        for instrument in PresetCatalog.all {
            let expected = "\(instrument.assetClass.rawValue):\(instrument.symbol)"
            #expect(instrument.id == expected, "Expected id '\(expected)' but got '\(instrument.id)'")
        }
    }

    @Test("Crypto providerIDs are lowercase CoinGecko ids")
    func cryptoProviderIDsAreLowercase() {
        for instrument in PresetCatalog.presets(for: .crypto) {
            #expect(instrument.providerID == instrument.providerID.lowercased(),
                    "Crypto providerID must be lowercase: \(instrument.providerID)")
            #expect(!instrument.providerID.isEmpty, "providerID must not be empty")
        }
    }

    @Test("VN equity providerIDs equal the symbol")
    func vnProviderIDsMatchSymbol() {
        for instrument in PresetCatalog.presets(for: .vnEquity) {
            #expect(instrument.providerID == instrument.symbol,
                    "VN providerID should equal symbol, got '\(instrument.providerID)' vs '\(instrument.symbol)'")
        }
    }

    @Test("Intl equity providerIDs equal the symbol")
    func intlProviderIDsMatchSymbol() {
        for instrument in PresetCatalog.presets(for: .intlEquity) {
            #expect(instrument.providerID == instrument.symbol,
                    "Intl providerID should equal symbol, got '\(instrument.providerID)' vs '\(instrument.symbol)'")
        }
    }

    @Test("All ids are unique")
    func idsAreUnique() {
        let ids = PresetCatalog.all.map(\.id)
        let unique = Set(ids)
        #expect(ids.count == unique.count, "Found duplicate ids in PresetCatalog.all")
    }

    @Test("Crypto assetClass is set correctly")
    func cryptoAssetClass() {
        for instrument in PresetCatalog.presets(for: .crypto) {
            #expect(instrument.assetClass == .crypto)
        }
    }

    @Test("VN assetClass is set correctly")
    func vnAssetClass() {
        for instrument in PresetCatalog.presets(for: .vnEquity) {
            #expect(instrument.assetClass == .vnEquity)
        }
    }

    @Test("Intl assetClass is set correctly")
    func intlAssetClass() {
        for instrument in PresetCatalog.presets(for: .intlEquity) {
            #expect(instrument.assetClass == .intlEquity)
        }
    }

    @Test("Known crypto providerIDs are correct CoinGecko ids")
    func knownCryptoProviderIDs() {
        let cryptoMap = Dictionary(uniqueKeysWithValues: PresetCatalog.presets(for: .crypto).map { ($0.symbol, $0.providerID) })
        #expect(cryptoMap["BTC"] == "bitcoin")
        #expect(cryptoMap["ETH"] == "ethereum")
        #expect(cryptoMap["BNB"] == "binancecoin")
        #expect(cryptoMap["AVAX"] == "avalanche-2")
        #expect(cryptoMap["LINK"] == "chainlink")
    }

    // MARK: - providerID(forSymbol:assetClass:) tests

    @Test("On-catalog crypto hit returns accurate CoinGecko id (BTC)")
    func providerIDCryptoBTC() {
        #expect(PresetCatalog.providerID(forSymbol: "BTC", assetClass: .crypto) == "bitcoin")
    }

    @Test("On-catalog crypto hit returns accurate CoinGecko id (BNB)")
    func providerIDCryptoBNB() {
        #expect(PresetCatalog.providerID(forSymbol: "BNB", assetClass: .crypto) == "binancecoin")
    }

    @Test("On-catalog crypto hit is case-insensitive")
    func providerIDCryptoCaseInsensitive() {
        #expect(PresetCatalog.providerID(forSymbol: "btc", assetClass: .crypto) == "bitcoin")
        #expect(PresetCatalog.providerID(forSymbol: "Eth", assetClass: .crypto) == "ethereum")
    }

    @Test("Off-catalog crypto falls back to lowercased symbol")
    func providerIDCryptoOffCatalog() {
        #expect(PresetCatalog.providerID(forSymbol: "SHIB", assetClass: .crypto) == "shib")
        #expect(PresetCatalog.providerID(forSymbol: "PEPE", assetClass: .crypto) == "pepe")
    }

    @Test("On-catalog VN equity returns symbol as providerID")
    func providerIDVNOnCatalog() {
        #expect(PresetCatalog.providerID(forSymbol: "FPT", assetClass: .vnEquity) == "FPT")
        #expect(PresetCatalog.providerID(forSymbol: "VCB", assetClass: .vnEquity) == "VCB")
    }

    @Test("Off-catalog VN equity falls back to symbol unchanged")
    func providerIDVNOffCatalog() {
        #expect(PresetCatalog.providerID(forSymbol: "HAX", assetClass: .vnEquity) == "HAX")
    }

    @Test("Off-catalog intl equity falls back to symbol unchanged")
    func providerIDIntlOffCatalog() {
        #expect(PresetCatalog.providerID(forSymbol: "NFLX", assetClass: .intlEquity) == "NFLX")
        #expect(PresetCatalog.providerID(forSymbol: "PLTR", assetClass: .intlEquity) == "PLTR")
    }

    // MARK: - Full crypto catalog accuracy

    @Test("All 10 crypto presets return exact CoinGecko ids via providerID helper")
    func providerIDAllCryptoPresets() {
        // Non-obvious mappings that would regress if the catalog or helper changes.
        let expectations: [(symbol: String, expected: String)] = [
            ("BTC",  "bitcoin"),
            ("ETH",  "ethereum"),
            ("BNB",  "binancecoin"),   // NOT "bnb"
            ("SOL",  "solana"),
            ("XRP",  "ripple"),
            ("ADA",  "cardano"),
            ("DOGE", "dogecoin"),
            ("TRX",  "tron"),
            ("AVAX", "avalanche-2"),   // NOT "avax"
            ("LINK", "chainlink"),
        ]
        for (symbol, expected) in expectations {
            let got = PresetCatalog.providerID(forSymbol: symbol, assetClass: .crypto)
            #expect(got == expected, "providerID(\(symbol)) expected '\(expected)', got '\(got)'")
        }
    }

    // MARK: - VN/intl on-catalog

    @Test("On-catalog intl equity returns symbol as providerID")
    func providerIDIntlOnCatalog() {
        #expect(PresetCatalog.providerID(forSymbol: "AAPL", assetClass: .intlEquity) == "AAPL")
        #expect(PresetCatalog.providerID(forSymbol: "MSFT", assetClass: .intlEquity) == "MSFT")
        #expect(PresetCatalog.providerID(forSymbol: "NVDA", assetClass: .intlEquity) == "NVDA")
    }

    // MARK: - Case-insensitivity: multiple variants for the same symbol

    @Test("providerID is case-insensitive: btc / BTC / Btc all return bitcoin")
    func providerIDCryptoAllCaseVariants() {
        #expect(PresetCatalog.providerID(forSymbol: "btc",  assetClass: .crypto) == "bitcoin")
        #expect(PresetCatalog.providerID(forSymbol: "BTC",  assetClass: .crypto) == "bitcoin")
        #expect(PresetCatalog.providerID(forSymbol: "Btc",  assetClass: .crypto) == "bitcoin")
        // AVAX is the trickiest: any case must still return "avalanche-2" not "avax"
        #expect(PresetCatalog.providerID(forSymbol: "avax", assetClass: .crypto) == "avalanche-2")
        #expect(PresetCatalog.providerID(forSymbol: "Avax", assetClass: .crypto) == "avalanche-2")
        // BNB: must return "binancecoin" not "bnb" regardless of input case
        #expect(PresetCatalog.providerID(forSymbol: "bnb",  assetClass: .crypto) == "binancecoin")
        #expect(PresetCatalog.providerID(forSymbol: "Bnb",  assetClass: .crypto) == "binancecoin")
    }

    // MARK: - Off-catalog fallback verification

    @Test("Off-catalog crypto fallback is always the lowercased input")
    func providerIDCryptoOffCatalogLowercasedInput() {
        // Even mixed-case off-catalog symbols are lowercased
        #expect(PresetCatalog.providerID(forSymbol: "SHIB",  assetClass: .crypto) == "shib")
        #expect(PresetCatalog.providerID(forSymbol: "shib",  assetClass: .crypto) == "shib")
        #expect(PresetCatalog.providerID(forSymbol: "Shib",  assetClass: .crypto) == "shib")
        #expect(PresetCatalog.providerID(forSymbol: "PEPE",  assetClass: .crypto) == "pepe")
        #expect(PresetCatalog.providerID(forSymbol: "WIF",   assetClass: .crypto) == "wif")
    }

    @Test("Off-catalog VN equity fallback preserves symbol case as-is")
    func providerIDVNOffCatalogPreservesCase() {
        // The helper returns symbol unchanged for vn/intl off-catalog.
        // The add form uppercases the symbol before calling, so in practice
        // this is always uppercase — but the helper must not alter the value.
        #expect(PresetCatalog.providerID(forSymbol: "CTG", assetClass: .vnEquity) == "CTG")
        #expect(PresetCatalog.providerID(forSymbol: "HAX", assetClass: .vnEquity) == "HAX")
    }

    // MARK: - Consistency invariant

    @Test("providerID helper matches preset.providerID for every instrument in the catalog")
    func providerIDConsistencyInvariant() {
        // For any preset in the catalog, the helper must return the same providerID
        // as the preset itself. This ensures the manual-add path (which calls the helper)
        // and the preset-add path produce identical providerID values — so dedupe and
        // pricing both work correctly when the same symbol is added by either route.
        for preset in PresetCatalog.all {
            let derived = PresetCatalog.providerID(forSymbol: preset.symbol, assetClass: preset.assetClass)
            #expect(
                derived == preset.providerID,
                "Consistency failure for \(preset.assetClass.rawValue):\(preset.symbol) — helper returned '\(derived)', preset.providerID is '\(preset.providerID)'"
            )
        }
    }
}
