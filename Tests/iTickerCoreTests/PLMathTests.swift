import Testing
@testable import iTickerCore

@Suite("PLMath Tests")
struct PLMathTests {

    let btcInstrument = Instrument(
        id: "bitcoin",
        symbol: "BTC",
        name: "Bitcoin",
        assetClass: .crypto,
        providerID: "bitcoin"
    )

    // MARK: Single holding

    @Test("Positive P/L")
    func positivePL() {
        let holding = HoldingDTO(instrument: btcInstrument, quantity: 1.0, averageCost: 50_000)
        let result = PLMath.compute(holding: holding, currentPrice: 60_000)

        #expect(result.costBasis == 50_000)
        #expect(result.marketValue == 60_000)
        #expect(result.unrealizedPL == 10_000)
        #expect(abs(result.unrealizedPLPct - 20.0) < 0.001)
    }

    @Test("Negative P/L")
    func negativePL() {
        let holding = HoldingDTO(instrument: btcInstrument, quantity: 2.0, averageCost: 30_000)
        let result = PLMath.compute(holding: holding, currentPrice: 25_000)

        #expect(result.costBasis == 60_000)
        #expect(result.marketValue == 50_000)
        #expect(result.unrealizedPL == -10_000)
        #expect(abs(result.unrealizedPLPct - (-16.666)) < 0.01)
    }

    @Test("Zero quantity holding")
    func zeroQuantity() {
        let holding = HoldingDTO(instrument: btcInstrument, quantity: 0.0, averageCost: 50_000)
        let result = PLMath.compute(holding: holding, currentPrice: 60_000)

        #expect(result.costBasis == 0)
        #expect(result.marketValue == 0)
        #expect(result.unrealizedPL == 0)
        #expect(result.unrealizedPLPct == 0)
    }

    @Test("Zero cost basis returns zero pct")
    func zeroCostBasis() {
        let holding = HoldingDTO(instrument: btcInstrument, quantity: 1.0, averageCost: 0.0)
        let result = PLMath.compute(holding: holding, currentPrice: 100)

        #expect(result.unrealizedPLPct == 0)
    }

    // MARK: Portfolio total

    @Test("Portfolio total with multiple holdings")
    func portfolioTotal() {
        let eth = Instrument(id: "ethereum", symbol: "ETH", name: "Ethereum", assetClass: .crypto, providerID: "ethereum")
        let holdings = [
            HoldingDTO(instrument: btcInstrument, quantity: 0.5, averageCost: 40_000),
            HoldingDTO(instrument: eth, quantity: 10, averageCost: 2_000),
        ]
        let btcQuote = Quote(instrument: btcInstrument, price: 60_000)
        let ethQuote = Quote(instrument: eth, price: 3_000)
        let quotes: [String: Quote] = [
            "bitcoin": btcQuote,
            "ethereum": ethQuote,
        ]

        let result = PLMath.portfolioTotal(holdings: holdings, quotes: quotes)
        // BTC: cost=20000, mktVal=30000, ETH: cost=20000, mktVal=30000
        #expect(result.costBasis == 40_000)
        #expect(result.marketValue == 60_000)
        #expect(result.unrealizedPL == 20_000)
        #expect(abs(result.unrealizedPLPct - 50.0) < 0.001)
    }

    @Test("Portfolio skips holding with no quote")
    func portfolioSkipsMissingQuote() {
        let holdings = [
            HoldingDTO(instrument: btcInstrument, quantity: 1.0, averageCost: 50_000),
        ]
        let result = PLMath.portfolioTotal(holdings: holdings, quotes: [:])

        #expect(result.costBasis == 0)
        #expect(result.marketValue == 0)
    }

    // MARK: Average cost

    @Test("Average cost for multi-lot")
    func averageCost() {
        // Existing: 1 BTC at 50k, adding 1 BTC at 60k → avg = 55k
        let avg = PLMath.averageCost(existingQty: 1, existingAvgCost: 50_000, newQty: 1, newPrice: 60_000)
        #expect(abs(avg - 55_000) < 0.01)
    }

    @Test("Average cost zero total quantity")
    func averageCostZeroTotal() {
        let avg = PLMath.averageCost(existingQty: 0, existingAvgCost: 0, newQty: 0, newPrice: 1000)
        #expect(avg == 0)
    }
}
