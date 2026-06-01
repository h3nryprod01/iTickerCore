import Testing
@testable import iTickerCore

@Suite("PLMath Edge Cases")
struct PLMathEdgeCaseTests {

    let btc = Instrument(
        id: "bitcoin",
        symbol: "BTC",
        name: "Bitcoin",
        assetClass: .crypto,
        providerID: "bitcoin"
    )

    let eth = Instrument(
        id: "ethereum",
        symbol: "ETH",
        name: "Ethereum",
        assetClass: .crypto,
        providerID: "ethereum"
    )

    // MARK: - Fractional crypto quantities

    @Test("Fractional quantity: 0.001 BTC")
    func fractionalQuantity() {
        let holding = HoldingDTO(instrument: btc, quantity: 0.001, averageCost: 50_000)
        let result = PLMath.compute(holding: holding, currentPrice: 60_000)

        #expect(abs(result.costBasis - 50.0) < 0.0001)
        #expect(abs(result.marketValue - 60.0) < 0.0001)
        #expect(abs(result.unrealizedPL - 10.0) < 0.0001)
        #expect(abs(result.unrealizedPLPct - 20.0) < 0.001)
    }

    @Test("Very small fractional quantity: 1e-8 BTC (satoshi)")
    func satoshiQuantity() {
        let holding = HoldingDTO(instrument: btc, quantity: 1e-8, averageCost: 50_000)
        let result = PLMath.compute(holding: holding, currentPrice: 100_000)

        // costBasis = 1e-8 * 50000 = 5e-4
        #expect(abs(result.costBasis - 5e-4) < 1e-9)
        #expect(abs(result.marketValue - 1e-3) < 1e-9)
        #expect(result.unrealizedPL > 0)
    }

    // MARK: - Zero price (current market price is zero)

    @Test("Zero current price means full loss")
    func zeroCurrentPrice() {
        let holding = HoldingDTO(instrument: btc, quantity: 1.0, averageCost: 50_000)
        let result = PLMath.compute(holding: holding, currentPrice: 0)

        #expect(result.marketValue == 0)
        #expect(result.unrealizedPL == -50_000)
        #expect(abs(result.unrealizedPLPct - (-100.0)) < 0.001)
    }

    // MARK: - Multiple lots average cost

    @Test("averageCost: adding first lot to empty position")
    func averageCostFirstLot() {
        // existingQty = 0, adding 5 units at 100
        let avg = PLMath.averageCost(existingQty: 0, existingAvgCost: 0, newQty: 5, newPrice: 100)
        #expect(abs(avg - 100.0) < 0.001)
    }

    @Test("averageCost: fractional lots")
    func averageCostFractionalLots() {
        // Existing: 0.5 BTC at 40k, adding 0.25 BTC at 60k
        // total cost = 0.5*40000 + 0.25*60000 = 20000 + 15000 = 35000
        // total qty = 0.75
        // avg = 35000 / 0.75 = 46666.67
        let avg = PLMath.averageCost(existingQty: 0.5, existingAvgCost: 40_000, newQty: 0.25, newPrice: 60_000)
        #expect(abs(avg - 46_666.666) < 0.01)
    }

    @Test("averageCost: large asymmetric lots")
    func averageCostAsymmetric() {
        // Existing: 100 VNM at 50k, adding 1 VNM at 100k
        // avg = (100*50000 + 1*100000) / 101 ≈ 50495.05
        let avg = PLMath.averageCost(existingQty: 100, existingAvgCost: 50_000, newQty: 1, newPrice: 100_000)
        let expected = (100.0 * 50_000 + 1.0 * 100_000) / 101.0
        #expect(abs(avg - expected) < 0.01)
    }

    // MARK: - Portfolio total edge cases

    @Test("Portfolio total with empty holdings returns zeros")
    func portfolioEmptyHoldings() {
        let quotes: [String: Quote] = [
            "bitcoin": Quote(instrument: btc, price: 60_000)
        ]
        let result = PLMath.portfolioTotal(holdings: [], quotes: quotes)
        #expect(result.costBasis == 0)
        #expect(result.marketValue == 0)
        #expect(result.unrealizedPL == 0)
        #expect(result.unrealizedPLPct == 0)
    }

    @Test("Portfolio total with zero cost basis holding")
    func portfolioZeroCostBasis() {
        let holding = HoldingDTO(instrument: btc, quantity: 1.0, averageCost: 0.0)
        let quotes: [String: Quote] = ["bitcoin": Quote(instrument: btc, price: 60_000)]
        let result = PLMath.portfolioTotal(holdings: [holding], quotes: quotes)

        #expect(result.costBasis == 0)
        #expect(result.marketValue == 60_000)
        // PLResult.unrealizedPLPct = 0 when costBasis == 0
        #expect(result.unrealizedPLPct == 0)
    }

    @Test("Portfolio total partial quotes: only matched holdings counted")
    func portfolioPartialQuotes() {
        let fpt = Instrument(id: "FPT", symbol: "FPT", name: "FPT Corp", assetClass: .vnEquity, providerID: "FPT")
        let holdings = [
            HoldingDTO(instrument: btc, quantity: 1.0, averageCost: 50_000),
            HoldingDTO(instrument: fpt, quantity: 100, averageCost: 90_000),
        ]
        // Only BTC quote available
        let quotes: [String: Quote] = ["bitcoin": Quote(instrument: btc, price: 60_000)]
        let result = PLMath.portfolioTotal(holdings: holdings, quotes: quotes)

        #expect(result.costBasis == 50_000)
        #expect(result.marketValue == 60_000)
    }

    @Test("PLResult: unrealizedPLPct is negative for loss position")
    func unrealizedPLPctNegative() {
        let result = PLResult(costBasis: 100, marketValue: 80)
        #expect(result.unrealizedPL == -20)
        #expect(abs(result.unrealizedPLPct - (-20.0)) < 0.001)
    }

    @Test("PLResult: unrealizedPLPct is 0 when cost and value equal")
    func unrealizedPLPctZero() {
        let result = PLResult(costBasis: 50_000, marketValue: 50_000)
        #expect(result.unrealizedPL == 0)
        #expect(result.unrealizedPLPct == 0)
    }
}
