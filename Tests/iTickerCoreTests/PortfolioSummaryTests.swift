import Testing
import Foundation
@testable import iTickerCore

// MARK: - Test instruments

private let vnStock = Instrument(
    id: "FPT",
    symbol: "FPT",
    name: "FPT Corporation",
    assetClass: .vnEquity,
    providerID: "FPT"
)

private let btc = Instrument(
    id: "bitcoin",
    symbol: "BTC",
    name: "Bitcoin",
    assetClass: .crypto,
    providerID: "bitcoin"
)

private let aapl = Instrument(
    id: "AAPL",
    symbol: "AAPL",
    name: "Apple Inc",
    assetClass: .intlEquity,
    providerID: "AAPL"
)

// MARK: - Known exchange rate for all tests

/// 1 USD = 25_000 VND (round number for easy hand-verification).
private let usdToVnd: Double = 25_000

@Suite("PortfolioSummary Tests")
struct PortfolioSummaryTests {

    // MARK: - Mixed holdings, USD display

    @Test("Mixed VN+crypto+intl totals are correct in USD")
    func mixedHoldingsUSD() {
        // FPT: 100 shares @ cost 90_000 VND, current price 100_000 VND
        //   → native value = 10_000_000 VND = 400 USD, native cost = 9_000_000 VND = 360 USD
        // BTC: 0.5 BTC @ cost 40_000 USD, current price 60_000 USD
        //   → native value = 30_000 USD, native cost = 20_000 USD
        // AAPL: 10 shares @ cost 180 USD, current price 200 USD
        //   → native value = 2_000 USD, native cost = 1_800 USD

        let holdings = [
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 90_000),
            HoldingDTO(instrument: btc,     quantity: 0.5, averageCost: 40_000),
            HoldingDTO(instrument: aapl,    quantity: 10,  averageCost: 180),
        ]
        let quotes: [String: Quote] = [
            "FPT":     Quote(instrument: vnStock, price: 100_000),
            "bitcoin": Quote(instrument: btc,     price: 60_000),
            "AAPL":    Quote(instrument: aapl,    price: 200),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .usd,
            usdToVnd: usdToVnd
        )

        // totalValue = 400 + 30_000 + 2_000 = 32_400 USD
        #expect(abs(summary.totalValue - 32_400) < 0.01)
        // totalCost = 360 + 20_000 + 1_800 = 22_160 USD
        #expect(abs(summary.totalCost - 22_160) < 0.01)
        // totalPL = 32_400 - 22_160 = 10_240 USD
        #expect(abs(summary.totalUnrealizedPL - 10_240) < 0.01)
        // totalPLPct = (10_240 / 22_160) * 100 ≈ 46.21%
        let expectedPct = (10_240.0 / 22_160.0) * 100
        #expect(abs(summary.totalUnrealizedPLPct - expectedPct) < 0.001)
        #expect(summary.currency == .usd)
    }

    // MARK: - Mixed holdings, VND display

    @Test("Mixed VN+crypto+intl totals are correct in VND")
    func mixedHoldingsVND() {
        // Same positions as above but in VND display.
        // FPT:  value = 10_000_000 VND, cost = 9_000_000 VND
        // BTC:  value = 30_000 * 25_000 = 750_000_000 VND, cost = 20_000 * 25_000 = 500_000_000 VND
        // AAPL: value = 2_000 * 25_000 = 50_000_000 VND,  cost = 1_800 * 25_000 = 45_000_000 VND

        let holdings = [
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 90_000),
            HoldingDTO(instrument: btc,     quantity: 0.5, averageCost: 40_000),
            HoldingDTO(instrument: aapl,    quantity: 10,  averageCost: 180),
        ]
        let quotes: [String: Quote] = [
            "FPT":     Quote(instrument: vnStock, price: 100_000),
            "bitcoin": Quote(instrument: btc,     price: 60_000),
            "AAPL":    Quote(instrument: aapl,    price: 200),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .vnd,
            usdToVnd: usdToVnd
        )

        let expectedValue = 10_000_000.0 + 750_000_000.0 + 50_000_000.0
        #expect(abs(summary.totalValue - expectedValue) < 0.01)
        let expectedCost = 9_000_000.0 + 500_000_000.0 + 45_000_000.0
        #expect(abs(summary.totalCost - expectedCost) < 0.01)
        let expectedPL = expectedValue - expectedCost
        #expect(abs(summary.totalUnrealizedPL - expectedPL) < 0.01)
        #expect(summary.currency == .vnd)
    }

    // MARK: - Allocation fractions

    @Test("Allocation fractions sum to ~1.0")
    func allocationFractionsSumToOne() {
        let holdings = [
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 90_000),
            HoldingDTO(instrument: btc,     quantity: 0.5, averageCost: 40_000),
            HoldingDTO(instrument: aapl,    quantity: 10,  averageCost: 180),
        ]
        let quotes: [String: Quote] = [
            "FPT":     Quote(instrument: vnStock, price: 100_000),
            "bitcoin": Quote(instrument: btc,     price: 60_000),
            "AAPL":    Quote(instrument: aapl,    price: 200),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .usd,
            usdToVnd: usdToVnd
        )

        let totalFraction = summary.allocations.map(\.fraction).reduce(0, +)
        #expect(abs(totalFraction - 1.0) < 0.0001)
    }

    @Test("Allocation ordering matches AssetClass.allCases order")
    func allocationOrdering() {
        let holdings = [
            HoldingDTO(instrument: aapl,    quantity: 10,  averageCost: 180),
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 90_000),
            HoldingDTO(instrument: btc,     quantity: 0.5, averageCost: 40_000),
        ]
        let quotes: [String: Quote] = [
            "FPT":     Quote(instrument: vnStock, price: 100_000),
            "bitcoin": Quote(instrument: btc,     price: 60_000),
            "AAPL":    Quote(instrument: aapl,    price: 200),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .usd,
            usdToVnd: usdToVnd
        )

        // allCases order: crypto, vnEquity, intlEquity
        #expect(summary.allocations.count == 3)
        #expect(summary.allocations[0].assetClass == .crypto)
        #expect(summary.allocations[1].assetClass == .vnEquity)
        #expect(summary.allocations[2].assetClass == .intlEquity)
    }

    @Test("Allocations only include classes with > 0 value")
    func allocationExcludesZeroClasses() {
        // Only VN equity — crypto and intlEquity should not appear.
        let holdings = [
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 90_000),
        ]
        let quotes: [String: Quote] = [
            "FPT": Quote(instrument: vnStock, price: 100_000),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .vnd,
            usdToVnd: usdToVnd
        )

        #expect(summary.allocations.count == 1)
        #expect(summary.allocations[0].assetClass == .vnEquity)
        #expect(abs(summary.allocations[0].fraction - 1.0) < 0.0001)
    }

    // MARK: - Edge cases

    @Test("Empty holdings returns zero summary")
    func emptyHoldings() {
        let summary = PLMath.portfolioSummary(
            holdings: [],
            quotes: [:],
            displayCurrency: .usd,
            usdToVnd: usdToVnd
        )
        #expect(summary.totalValue == 0)
        #expect(summary.totalCost == 0)
        #expect(summary.totalUnrealizedPL == 0)
        #expect(summary.totalUnrealizedPLPct == 0)
        #expect(summary.allocations.isEmpty)
    }

    @Test("Holding with missing quote is skipped")
    func missingQuoteSkipped() {
        let holdings = [
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 90_000),
            HoldingDTO(instrument: btc,     quantity: 0.5, averageCost: 40_000),
        ]
        // Only VN stock has a quote; BTC is missing.
        let quotes: [String: Quote] = [
            "FPT": Quote(instrument: vnStock, price: 100_000),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .vnd,
            usdToVnd: usdToVnd
        )

        // Only FPT contributes: value = 10_000_000 VND
        #expect(abs(summary.totalValue - 10_000_000) < 0.01)
        #expect(summary.allocations.count == 1)
        #expect(summary.allocations[0].assetClass == .vnEquity)
    }

    @Test("Zero cost returns 0% P/L")
    func zeroCostReturnsZeroPLPct() {
        let holding = HoldingDTO(instrument: btc, quantity: 1.0, averageCost: 0.0)
        let quotes: [String: Quote] = [
            "bitcoin": Quote(instrument: btc, price: 60_000),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: [holding],
            quotes: quotes,
            displayCurrency: .usd,
            usdToVnd: usdToVnd
        )

        #expect(summary.totalCost == 0)
        #expect(summary.totalUnrealizedPLPct == 0)
    }

    // MARK: - VN+Crypto mixed-currency (post-scaling)

    @Test("VN holding at true VND (scaled) + crypto USD — correct USD total")
    func vnScaledPlusCryptoUSD() {
        // After TCBS ×1000 scaling, FPT is 72900 VND per share.
        // 100 shares @ cost 70000 VND each → nativeValue=7290000, nativeCost=7000000
        // BTC: 0.1 @ 60000 USD → nativeValue=6000 USD, nativeCost=5000 USD
        // At rate 25000: FPT USD value = 7290000/25000 = 291.6, cost = 280

        let holdings = [
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 70_000),
            HoldingDTO(instrument: btc,     quantity: 0.1, averageCost: 50_000),
        ]
        let quotes: [String: Quote] = [
            "FPT":     Quote(instrument: vnStock, price: 72_900, currency: "VND"),
            "bitcoin": Quote(instrument: btc,     price: 60_000, currency: "USD"),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .usd,
            usdToVnd: usdToVnd
        )

        let expectedFPTusd = (100 * 72_900.0) / usdToVnd  // 291.6
        let expectedBTCusd = 0.1 * 60_000.0               // 6_000.0
        #expect(abs(summary.totalValue - (expectedFPTusd + expectedBTCusd)) < 0.01)
        #expect(summary.currency == .usd)
    }

    @Test("VN holding at true VND (scaled) + crypto USD — correct VND total")
    func vnScaledPlusCryptoVND() {
        // Same positions expressed in VND display
        // FPT: 100 × 72900 = 7290000 VND
        // BTC: 0.1 × 60000 × 25000 = 150000000 VND

        let holdings = [
            HoldingDTO(instrument: vnStock, quantity: 100, averageCost: 70_000),
            HoldingDTO(instrument: btc,     quantity: 0.1, averageCost: 50_000),
        ]
        let quotes: [String: Quote] = [
            "FPT":     Quote(instrument: vnStock, price: 72_900, currency: "VND"),
            "bitcoin": Quote(instrument: btc,     price: 60_000, currency: "USD"),
        ]

        let summary = PLMath.portfolioSummary(
            holdings: holdings,
            quotes: quotes,
            displayCurrency: .vnd,
            usdToVnd: usdToVnd
        )

        let expectedFPTvnd = 100 * 72_900.0          // 7_290_000
        let expectedBTCvnd = 0.1 * 60_000.0 * usdToVnd  // 150_000_000
        #expect(abs(summary.totalValue - (expectedFPTvnd + expectedBTCvnd)) < 0.01)
        #expect(summary.currency == .vnd)
    }

    @Test("Invalid usdToVnd (<= 0) falls back to 1.0 without crashing")
    func invalidExchangeRateFallback() {
        let holding = HoldingDTO(instrument: btc, quantity: 1.0, averageCost: 50_000)
        let quotes: [String: Quote] = [
            "bitcoin": Quote(instrument: btc, price: 60_000),
        ]

        // Should not crash; rate falls back to 1.0
        let summary = PLMath.portfolioSummary(
            holdings: [holding],
            quotes: quotes,
            displayCurrency: .usd,
            usdToVnd: -1.0   // invalid
        )

        // With rate=1.0, USD→USD conversion is identity
        #expect(abs(summary.totalValue - 60_000) < 0.01)
    }
}
