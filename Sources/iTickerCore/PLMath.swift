import Foundation

// MARK: - P/L computation

public struct PLResult: Sendable {
    public let costBasis: Double
    public let marketValue: Double
    public let unrealizedPL: Double
    public let unrealizedPLPct: Double

    public init(costBasis: Double, marketValue: Double) {
        self.costBasis = costBasis
        self.marketValue = marketValue
        self.unrealizedPL = marketValue - costBasis
        self.unrealizedPLPct = costBasis == 0 ? 0 : (marketValue - costBasis) / costBasis * 100
    }
}

public enum PLMath {

    /// Compute P/L for a single holding given its current price.
    public static func compute(holding: HoldingDTO, currentPrice: Double) -> PLResult {
        let costBasis = holding.quantity * holding.averageCost
        let marketValue = holding.quantity * currentPrice
        return PLResult(costBasis: costBasis, marketValue: marketValue)
    }

    /// Aggregate portfolio P/L across multiple holdings.
    /// Holdings without a matching quote are skipped (no price = no market value).
    public static func portfolioTotal(
        holdings: [HoldingDTO],
        quotes: [String: Quote]           // keyed by Instrument.id
    ) -> PLResult {
        var totalCost = 0.0
        var totalMarket = 0.0

        for holding in holdings {
            guard let quote = quotes[holding.instrument.id] else { continue }
            let result = compute(holding: holding, currentPrice: quote.price)
            totalCost += result.costBasis
            totalMarket += result.marketValue
        }

        return PLResult(costBasis: totalCost, marketValue: totalMarket)
    }

    /// Weighted-average cost for adding a new lot to an existing position.
    public static func averageCost(
        existingQty: Double,
        existingAvgCost: Double,
        newQty: Double,
        newPrice: Double
    ) -> Double {
        let totalQty = existingQty + newQty
        guard totalQty > 0 else { return 0 }
        let totalCost = existingQty * existingAvgCost + newQty * newPrice
        return totalCost / totalQty
    }
}
