import Testing
import Foundation
@testable import iTickerCore

@Suite("OnboardingSeed Tests")
struct OnboardingSeedTests {

    // MARK: - presets(forSelected:perClass:)

    @Test("Empty selection returns empty array")
    func emptySelection() {
        let result = OnboardingSeed.presets(forSelected: [])
        #expect(result.isEmpty)
    }

    @Test("Crypto-only returns 5 crypto instruments")
    func cryptoOnly() {
        let result = OnboardingSeed.presets(forSelected: [.crypto])
        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.assetClass == .crypto })
    }

    @Test("VN-only returns 5 VN equity instruments")
    func vnOnly() {
        let result = OnboardingSeed.presets(forSelected: [.vnEquity])
        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.assetClass == .vnEquity })
    }

    @Test("Intl-only returns 5 international equity instruments")
    func intlOnly() {
        let result = OnboardingSeed.presets(forSelected: [.intlEquity])
        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.assetClass == .intlEquity })
    }

    @Test("All classes selected returns 15 instruments (5 per class)")
    func allClassesSelected() {
        let result = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity])
        #expect(result.count == 15)
    }

    @Test("Crypto + VN selected returns 10 instruments")
    func cryptoPlusVN() {
        let result = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity])
        #expect(result.count == 10)
        let classes = Set(result.map(\.assetClass))
        #expect(classes == [.crypto, .vnEquity])
    }

    @Test("Results are deduplicated — no duplicate ids")
    func noDuplicateIDs() {
        let result = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity])
        let ids = result.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test("Results are deterministic on repeated calls")
    func deterministic() {
        let first  = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity])
        let second = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity])
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("Custom perClass parameter is respected")
    func customPerClass() {
        let result = OnboardingSeed.presets(forSelected: [.crypto], perClass: 3)
        #expect(result.count == 3)
        #expect(result.allSatisfy { $0.assetClass == .crypto })
    }

    @Test("perClass larger than catalog returns all available instruments")
    func perClassLargerThanCatalog() {
        // Each class has 10 presets; requesting 100 should return all 10
        let result = OnboardingSeed.presets(forSelected: [.crypto], perClass: 100)
        #expect(result.count == 10)
    }

    @Test("Order follows AssetClass.allCases then PresetCatalog order within class")
    func deterministicOrder() {
        let result = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity])
        // First 5 must be crypto (allCases order: crypto, vnEquity, intlEquity)
        #expect(result.prefix(5).allSatisfy { $0.assetClass == .crypto })
        #expect(result[5..<10].allSatisfy { $0.assetClass == .vnEquity })
        #expect(result[10..<15].allSatisfy { $0.assetClass == .intlEquity })
        // First crypto item must be BTC (first in PresetCatalog.cryptoPresets)
        #expect(result[0].symbol == "BTC")
    }

    // MARK: - defaultCurrency(forSelected:)

    @Test("VN-only selection → VND")
    func vnOnlyCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: [.vnEquity]) == .vnd)
    }

    @Test("VN + Crypto selection → VND")
    func vnPlusCryptoCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: [.vnEquity, .crypto]) == .vnd)
    }

    @Test("VN + Intl selection → VND")
    func vnPlusIntlCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: [.vnEquity, .intlEquity]) == .vnd)
    }

    @Test("All classes selected → VND (VN present)")
    func allSelectedCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: [.crypto, .vnEquity, .intlEquity]) == .vnd)
    }

    @Test("Crypto-only selection → USD")
    func cryptoOnlyCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: [.crypto]) == .usd)
    }

    @Test("Intl-only selection → USD")
    func intlOnlyCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: [.intlEquity]) == .usd)
    }

    @Test("Crypto + Intl (no VN) → USD")
    func cryptoPlusIntlCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: [.crypto, .intlEquity]) == .usd)
    }

    @Test("Empty selection → USD")
    func emptySelectionCurrency() {
        #expect(OnboardingSeed.defaultCurrency(forSelected: []) == .usd)
    }

    // MARK: - Additional coverage: ID format + assetClass containment

    @Test("All returned IDs follow '<assetClassRaw>:<symbol>' format")
    func idFormat() {
        let result = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity])
        for instrument in result {
            let prefix = instrument.assetClass.rawValue + ":"
            #expect(instrument.id.hasPrefix(prefix), "id '\(instrument.id)' must start with '\(prefix)'")
            let symbol = String(instrument.id.dropFirst(prefix.count))
            #expect(symbol == instrument.symbol, "id '\(instrument.id)' symbol component must equal symbol '\(instrument.symbol)'")
        }
    }

    @Test("Every returned instrument's assetClass is in the selected set")
    func assetClassContainment() {
        let selected: Set<AssetClass> = [.crypto, .intlEquity]
        let result = OnboardingSeed.presets(forSelected: selected)
        #expect(result.allSatisfy { selected.contains($0.assetClass) })
    }

    @Test("VN-only: returned assetClasses are strictly .vnEquity")
    func vnOnlyAssetClassContainment() {
        let result = OnboardingSeed.presets(forSelected: [.vnEquity])
        #expect(result.allSatisfy { $0.assetClass == .vnEquity })
    }

    @Test("total count equals perClass * number of selected classes")
    func totalCountEqualsPerClassTimesSelected() {
        let perClass = 3
        let selected: Set<AssetClass> = [.crypto, .vnEquity, .intlEquity]
        let result = OnboardingSeed.presets(forSelected: selected, perClass: perClass)
        #expect(result.count == perClass * selected.count)
    }

    @Test("perClass=1 returns exactly one instrument per selected class")
    func perClassOne() {
        let selected: Set<AssetClass> = [.crypto, .vnEquity]
        let result = OnboardingSeed.presets(forSelected: selected, perClass: 1)
        #expect(result.count == 1 * selected.count)
        // One of each class
        let classes = Set(result.map(\.assetClass))
        #expect(classes == selected)
    }

    @Test("perClass=0 returns empty array even for non-empty selection")
    func perClassZero() {
        let result = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity], perClass: 0)
        #expect(result.isEmpty)
    }

    @Test("all-three selected with perClass=5 returns exactly 15 instruments")
    func allThreePerClassFiveReturns15() {
        let result = OnboardingSeed.presets(forSelected: [.crypto, .vnEquity, .intlEquity], perClass: 5)
        #expect(result.count == 15)
    }

    @Test("Crypto + Intl selected with perClass=2 returns 4 instruments, all in selected set")
    func cryptoPlusIntlPerClass2() {
        let selected: Set<AssetClass> = [.crypto, .intlEquity]
        let result = OnboardingSeed.presets(forSelected: selected, perClass: 2)
        #expect(result.count == 4)
        #expect(result.allSatisfy { selected.contains($0.assetClass) })
    }
}
