import Testing
import Foundation
@testable import iTickerCore

// MARK: - Currency Defaults Tests

@Suite("Currency defaults")
struct CurrencyDefaultsTests {

    // MARK: AssetClass.defaultCurrencyCode

    @Test("crypto defaultCurrencyCode is USD")
    func cryptoDefaultsToUSD() {
        #expect(AssetClass.crypto.defaultCurrencyCode == "USD")
    }

    @Test("intlEquity defaultCurrencyCode is USD")
    func intlEquityDefaultsToUSD() {
        #expect(AssetClass.intlEquity.defaultCurrencyCode == "USD")
    }

    @Test("vnEquity defaultCurrencyCode is VND")
    func vnEquityDefaultsToVND() {
        #expect(AssetClass.vnEquity.defaultCurrencyCode == "VND")
    }

    // MARK: Instrument.currencyCode defaults

    @Test("Instrument(crypto) defaults to USD when currencyCode omitted")
    func cryptoInstrumentDefaultsUSD() {
        let btc = Instrument(id: "bitcoin", symbol: "BTC", name: "Bitcoin",
                             assetClass: .crypto, providerID: "bitcoin")
        #expect(btc.currencyCode == "USD")
    }

    @Test("Instrument(vnEquity) defaults to VND when currencyCode omitted")
    func vnInstrumentDefaultsVND() {
        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp",
                             assetClass: .vnEquity, providerID: "FPT")
        #expect(fpt.currencyCode == "VND")
    }

    @Test("Instrument(intlEquity) defaults to USD when currencyCode omitted")
    func intlInstrumentDefaultsUSD() {
        let aapl = Instrument(id: "AAPL", symbol: "AAPL", name: "Apple",
                              assetClass: .intlEquity, providerID: "AAPL")
        #expect(aapl.currencyCode == "USD")
    }

    @Test("Instrument respects explicit currencyCode override")
    func instrumentRespectsExplicitCurrencyCode() {
        let mc = Instrument(id: "MC.PA", symbol: "MC", name: "LVMH",
                            assetClass: .intlEquity, providerID: "MC.PA",
                            currencyCode: "EUR")
        #expect(mc.currencyCode == "EUR")
    }

    @Test("Instrument Codable round-trip preserves currencyCode")
    func instrumentRoundTrip() throws {
        let mc = Instrument(id: "MC.PA", symbol: "MC", name: "LVMH",
                            assetClass: .intlEquity, providerID: "MC.PA",
                            currencyCode: "EUR")
        let data = try JSONEncoder().encode(mc)
        let decoded = try JSONDecoder().decode(Instrument.self, from: data)
        #expect(decoded.currencyCode == "EUR")
        #expect(decoded.id == mc.id)
    }

    @Test("Instrument Hashable still works with currencyCode field")
    func instrumentHashable() {
        let a = Instrument(id: "BTC", symbol: "BTC", name: "Bitcoin",
                           assetClass: .crypto, providerID: "bitcoin",
                           currencyCode: "USD")
        let b = Instrument(id: "BTC", symbol: "BTC", name: "Bitcoin",
                           assetClass: .crypto, providerID: "bitcoin",
                           currencyCode: "USD")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
