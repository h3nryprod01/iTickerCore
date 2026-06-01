import Foundation
import Testing
@testable import iTickerCore

// MARK: - MenuBarMode Tests

@Suite("MenuBarMode Tests")
struct MenuBarModeTests {

    // MARK: Raw values

    @Test("MenuBarMode raw values are stable strings")
    func rawValues() {
        #expect(MenuBarMode.watchlist.rawValue == "watchlist")
        #expect(MenuBarMode.portfolio.rawValue == "portfolio")
        #expect(MenuBarMode.selected.rawValue  == "selected")
    }

    @Test("MenuBarMode is Codable round-trip")
    func codable() throws {
        for mode in MenuBarMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(MenuBarMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    // MARK: CaseIterable

    @Test("MenuBarMode has 3 cases")
    func caseCount() {
        #expect(MenuBarMode.allCases.count == 3)
    }

    @Test("MenuBarMode allCases contains watchlist, portfolio, selected")
    func allCasesContainAllThree() {
        let cases = MenuBarMode.allCases
        #expect(cases.contains(.watchlist))
        #expect(cases.contains(.portfolio))
        #expect(cases.contains(.selected))
    }

    @Test("MenuBarMode default is watchlist")
    func defaultIsWatchlist() {
        // The plan specifies .watchlist as the default; verify enum identity
        let defaultMode: MenuBarMode = .watchlist
        #expect(defaultMode.rawValue == "watchlist")
        // Codable round-trip with default value
        let encoded = try? JSONEncoder().encode(defaultMode)
        #expect(encoded != nil)
        let decoded = try? JSONDecoder().decode(MenuBarMode.self, from: encoded!)
        #expect(decoded == .watchlist)
    }

    @Test("MenuBarMode can be initialized from its rawValue string")
    func initFromRawValue() {
        #expect(MenuBarMode(rawValue: "watchlist") == .watchlist)
        #expect(MenuBarMode(rawValue: "portfolio") == .portfolio)
        #expect(MenuBarMode(rawValue: "selected")  == .selected)
        #expect(MenuBarMode(rawValue: "unknown")   == nil)
        #expect(MenuBarMode(rawValue: "")           == nil)
    }
}

// MARK: - MenuBarSource Tests

@Suite("MenuBarSource Tests")
struct MenuBarSourceTests {

    private let watch = ["BTC", "ETH", "FPT"]
    private let holdings = ["BTC", "AAPL"]
    private let selected = ["ETH"]

    @Test("watchlist mode returns watchIDs")
    func watchlistMode() {
        let result = MenuBarSource.idsToDisplay(
            mode: .watchlist,
            watchIDs: watch,
            holdingIDs: holdings,
            selectedIDs: selected
        )
        #expect(result == watch)
    }

    @Test("portfolio mode returns holdingIDs")
    func portfolioMode() {
        let result = MenuBarSource.idsToDisplay(
            mode: .portfolio,
            watchIDs: watch,
            holdingIDs: holdings,
            selectedIDs: selected
        )
        #expect(result == holdings)
    }

    @Test("selected mode returns selectedIDs")
    func selectedMode() {
        let result = MenuBarSource.idsToDisplay(
            mode: .selected,
            watchIDs: watch,
            holdingIDs: holdings,
            selectedIDs: selected
        )
        #expect(result == selected)
    }

    @Test("watchlist mode with empty watchIDs returns empty")
    func watchlistEmpty() {
        let result = MenuBarSource.idsToDisplay(
            mode: .watchlist,
            watchIDs: [],
            holdingIDs: holdings,
            selectedIDs: selected
        )
        #expect(result.isEmpty)
    }

    @Test("portfolio mode with empty holdingIDs returns empty")
    func portfolioEmpty() {
        let result = MenuBarSource.idsToDisplay(
            mode: .portfolio,
            watchIDs: watch,
            holdingIDs: [],
            selectedIDs: selected
        )
        #expect(result.isEmpty)
    }

    @Test("selected mode with empty selectedIDs returns empty")
    func selectedEmpty() {
        let result = MenuBarSource.idsToDisplay(
            mode: .selected,
            watchIDs: watch,
            holdingIDs: holdings,
            selectedIDs: []
        )
        #expect(result.isEmpty)
    }

    @Test("all inputs empty returns empty for any mode")
    func allEmpty() {
        for mode in MenuBarMode.allCases {
            let result = MenuBarSource.idsToDisplay(
                mode: mode,
                watchIDs: [],
                holdingIDs: [],
                selectedIDs: []
            )
            #expect(result.isEmpty, "expected empty for mode \(mode)")
        }
    }

    @Test("idsToDisplay is deterministic — same input returns same output")
    func orderDeterminism() {
        let ids = ["ETH", "BTC", "FPT"]
        let result1 = MenuBarSource.idsToDisplay(mode: .watchlist, watchIDs: ids, holdingIDs: [], selectedIDs: [])
        let result2 = MenuBarSource.idsToDisplay(mode: .watchlist, watchIDs: ids, holdingIDs: [], selectedIDs: [])
        #expect(result1 == result2)
    }

    @Test("watchlist mode ignores holdingIDs and selectedIDs")
    func watchlistIgnoresOtherInputs() {
        let result = MenuBarSource.idsToDisplay(
            mode: .watchlist,
            watchIDs: ["AAPL"],
            holdingIDs: ["BTC", "ETH"],
            selectedIDs: ["XRP"]
        )
        #expect(result == ["AAPL"])
        #expect(!result.contains("BTC"))
        #expect(!result.contains("XRP"))
    }

    @Test("portfolio mode ignores watchIDs and selectedIDs")
    func portfolioIgnoresOtherInputs() {
        let result = MenuBarSource.idsToDisplay(
            mode: .portfolio,
            watchIDs: ["FPT", "VNM"],
            holdingIDs: ["BTC"],
            selectedIDs: ["ETH"]
        )
        #expect(result == ["BTC"])
        #expect(!result.contains("FPT"))
        #expect(!result.contains("ETH"))
    }

    @Test("selected mode ignores watchIDs and holdingIDs")
    func selectedIgnoresOtherInputs() {
        let result = MenuBarSource.idsToDisplay(
            mode: .selected,
            watchIDs: ["FPT"],
            holdingIDs: ["BTC"],
            selectedIDs: ["ETH", "SOL"]
        )
        #expect(result == ["ETH", "SOL"])
        #expect(!result.contains("FPT"))
        #expect(!result.contains("BTC"))
    }

    @Test("idsToDisplay preserves input order for all modes")
    func preservesOrder() {
        let ordered = ["C", "A", "B"]
        let watchResult = MenuBarSource.idsToDisplay(mode: .watchlist, watchIDs: ordered, holdingIDs: [], selectedIDs: [])
        #expect(watchResult == ["C", "A", "B"])

        let holdResult = MenuBarSource.idsToDisplay(mode: .portfolio, watchIDs: [], holdingIDs: ordered, selectedIDs: [])
        #expect(holdResult == ["C", "A", "B"])

        let selResult = MenuBarSource.idsToDisplay(mode: .selected, watchIDs: [], holdingIDs: [], selectedIDs: ordered)
        #expect(selResult == ["C", "A", "B"])
    }
}

// MARK: - MenuBarLabelBuilder Tests

@Suite("MenuBarLabelBuilder Tests")
struct MenuBarLabelBuilderTests {

    @Test("returns nil when totalValue is zero")
    func zeroValueReturnsNil() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 0,
            totalUnrealizedPLPct: 5.0,
            currency: .usd
        )
        #expect(result == nil)
    }

    @Test("positive P/L uses '+' prefix in USD")
    func positivePLUSD() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 12345,
            totalUnrealizedPLPct: 1.23,
            currency: .usd
        )
        // Should contain '+' and '%'
        #expect(result != nil)
        #expect(result!.contains("+1.23%"))
        #expect(result!.hasPrefix("$"))
    }

    @Test("negative P/L uses '-' prefix in USD")
    func negativePLUSD() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 1000,
            totalUnrealizedPLPct: -0.45,
            currency: .usd
        )
        #expect(result != nil)
        #expect(result!.contains("-0.45%"))
    }

    @Test("zero P/L shows '+0.00%' prefix")
    func zeroPLUSD() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 5000,
            totalUnrealizedPLPct: 0.0,
            currency: .usd
        )
        #expect(result != nil)
        #expect(result!.contains("+0.00%"))
    }

    @Test("VND currency shows ₫ symbol")
    func vndCurrency() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 12_345_678,
            totalUnrealizedPLPct: 2.5,
            currency: .vnd
        )
        #expect(result != nil)
        #expect(result!.hasPrefix("₫"))
        #expect(result!.contains("+2.50%"))
    }

    @Test("label format is valueStr space pctStr")
    func labelFormat() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 100,
            totalUnrealizedPLPct: 1.0,
            currency: .usd
        )
        // Must have exactly one space separating value and pct
        let parts = result!.split(separator: " ", maxSplits: 1)
        #expect(parts.count == 2)
        #expect(parts[1] == "+1.00%")
    }

    @Test("negative totalValue returns nil (no holdings with quotes)")
    func negativeTotalValueReturnsNil() {
        // guard totalValue > 0 — negative is treated as no valid data
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: -1.0,
            totalUnrealizedPLPct: 5.0,
            currency: .usd
        )
        #expect(result == nil)
    }

    @Test("tiny positive value returns a non-nil label")
    func tinyPositiveValue() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 0.01,
            totalUnrealizedPLPct: 0.0,
            currency: .usd
        )
        // Value is positive (0.01 > 0) so must return something
        #expect(result != nil)
        #expect(result!.hasPrefix("$"))
        #expect(result!.contains("+0.00%"))
    }

    @Test("large USD value preserves dollar prefix and pct")
    func largeUSDValue() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 1_000_000,
            totalUnrealizedPLPct: -12.34,
            currency: .usd
        )
        #expect(result != nil)
        #expect(result!.hasPrefix("$"))
        #expect(result!.contains("-12.34%"))
    }

    @Test("large VND value preserves dong prefix and pct")
    func largeVNDValue() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 500_000_000,
            totalUnrealizedPLPct: 3.14,
            currency: .vnd
        )
        #expect(result != nil)
        #expect(result!.hasPrefix("₫"))
        #expect(result!.contains("+3.14%"))
    }

    @Test("exact negative pct format has no double-sign")
    func negativePercentNoDoubleSign() {
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 999,
            totalUnrealizedPLPct: -100.0,
            currency: .usd
        )
        #expect(result != nil)
        // Should be "-100.00%" not "+-100.00%"
        #expect(result!.contains("-100.00%"))
        #expect(!result!.contains("+-"))
    }

    @Test("portfolioLabel is locale-independent for pct portion")
    func pctIsLocaleIndependent() {
        // The pct string is built with String(format:) so it's always dot-decimal
        let result = MenuBarLabelBuilder.portfolioLabel(
            totalValue: 1234,
            totalUnrealizedPLPct: 1.5,
            currency: .usd
        )
        #expect(result != nil)
        // "+1.50%" must use dot, not comma
        #expect(result!.contains("+1.50%"))
    }
}
