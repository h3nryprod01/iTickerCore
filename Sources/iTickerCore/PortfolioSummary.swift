import Foundation

// MARK: - DisplayCurrency

public enum DisplayCurrency: String, Sendable, CaseIterable {
    case usd
    case vnd
}

// MARK: - AllocationSlice

/// A per-asset-class allocation breakdown.
public struct AllocationSlice: Sendable {
    /// The asset class this slice represents.
    public let assetClass: AssetClass
    /// The total market value in display currency.
    public let value: Double
    /// Fraction of the total portfolio value in [0, 1].
    public let fraction: Double

    public init(assetClass: AssetClass, value: Double, fraction: Double) {
        self.assetClass = assetClass
        self.value = value
        self.fraction = fraction
    }
}

// MARK: - PortfolioSummary

/// An immutable snapshot of aggregated portfolio metrics in a chosen display currency.
public struct PortfolioSummary: Sendable {
    /// Total market value across all holdings, in display currency.
    public let totalValue: Double
    /// Total cost basis across all holdings, in display currency.
    public let totalCost: Double
    /// Total unrealized P/L in display currency.
    public let totalUnrealizedPL: Double
    /// Total unrealized P/L as a percentage. Zero when totalCost == 0.
    public let totalUnrealizedPLPct: Double
    /// Per-asset-class allocations, ordered by AssetClass.allCases order.
    /// Only classes with > 0 value are included.
    public let allocations: [AllocationSlice]
    /// The currency all monetary fields are expressed in.
    public let currency: DisplayCurrency

    public init(
        totalValue: Double,
        totalCost: Double,
        totalUnrealizedPL: Double,
        totalUnrealizedPLPct: Double,
        allocations: [AllocationSlice],
        currency: DisplayCurrency
    ) {
        self.totalValue = totalValue
        self.totalCost = totalCost
        self.totalUnrealizedPL = totalUnrealizedPL
        self.totalUnrealizedPLPct = totalUnrealizedPLPct
        self.allocations = allocations
        self.currency = currency
    }
}

// MARK: - Currency convention

/// Native currency by asset class:
///   - `.vnEquity`    → VND  (prices and averageCost are in VND)
///   - `.crypto`      → USD  (prices and averageCost are in USD)
///   - `.intlEquity`  → USD  (prices and averageCost are in USD)
///
/// `averageCost` on each HoldingDTO is in the holding's own native currency,
/// consistent with the quote price returned by the corresponding provider.
///
/// Watchlist / Detail rows display each instrument in its NATIVE currency via
/// `Quote.currency`. The `displayCurrency` USD/VND picker here governs ONLY
/// the AGGREGATE totals in the portfolio view and the menu-bar portfolio label.
///
/// Limitation: EUR/GBP/JPY intl equities are treated as USD-native for aggregate
/// totals (no multi-currency FX beyond USD↔VND). They display correctly in
/// native currency on watchlist rows, but in aggregates they are summed at face
/// value as USD. This is an acknowledged limitation, not a bug.

private extension AssetClass {
    /// Returns true when the holding's native currency is VND.
    var isVND: Bool { self == .vnEquity }
}

// MARK: - Aggregation (placed in PortfolioSummary.swift for cohesion with the value types)

extension PLMath {

    /// Compute a portfolio summary across multiple holdings.
    ///
    /// - Parameters:
    ///   - holdings: The user's holdings. Each holding's `averageCost` is in the
    ///     holding's **native currency** (VND for `.vnEquity`, USD for everything else).
    ///   - quotes: Current quotes keyed by `Instrument.id`. Holdings without a quote
    ///     are **skipped** — they do not contribute to totals.
    ///   - displayCurrency: The currency to express all monetary outputs in.
    ///   - usdToVnd: Exchange rate (1 USD = N VND). If <= 0, falls back to 1.0 and
    ///     no currency conversion is applied; this avoids division-by-zero while still
    ///     producing a result.
    /// - Returns: An immutable `PortfolioSummary` in the requested display currency.
    public static func portfolioSummary(
        holdings: [HoldingDTO],
        quotes: [String: Quote],
        displayCurrency: DisplayCurrency,
        usdToVnd: Double
    ) -> PortfolioSummary {
        // Guard against nonsensical exchange rate.
        let rate = usdToVnd > 0 ? usdToVnd : 1.0

        var totalValue = 0.0
        var totalCost = 0.0
        // Accumulate per-class value in display currency.
        var classValues: [AssetClass: Double] = [:]

        for holding in holdings {
            guard let quote = quotes[holding.instrument.id] else { continue }

            let nativeValue = holding.quantity * quote.price
            let nativeCost  = holding.quantity * holding.averageCost
            let assetClass  = holding.instrument.assetClass

            // Convert native → display currency.
            let displayValue: Double
            let displayCost: Double
            if assetClass.isVND {
                // Native is VND.
                switch displayCurrency {
                case .vnd:
                    displayValue = nativeValue
                    displayCost  = nativeCost
                case .usd:
                    displayValue = nativeValue / rate
                    displayCost  = nativeCost  / rate
                }
            } else {
                // Native is USD.
                switch displayCurrency {
                case .usd:
                    displayValue = nativeValue
                    displayCost  = nativeCost
                case .vnd:
                    displayValue = nativeValue * rate
                    displayCost  = nativeCost  * rate
                }
            }

            totalValue += displayValue
            totalCost  += displayCost
            classValues[assetClass, default: 0.0] += displayValue
        }

        let totalPL    = totalValue - totalCost
        let totalPLPct = totalCost == 0 ? 0.0 : (totalPL / totalCost) * 100

        // Build allocations in deterministic AssetClass.allCases order.
        let allocations: [AllocationSlice] = AssetClass.allCases.compactMap { cls in
            guard let value = classValues[cls], value > 0 else { return nil }
            let fraction = totalValue == 0 ? 0.0 : value / totalValue
            return AllocationSlice(assetClass: cls, value: value, fraction: fraction)
        }

        return PortfolioSummary(
            totalValue: totalValue,
            totalCost: totalCost,
            totalUnrealizedPL: totalPL,
            totalUnrealizedPLPct: totalPLPct,
            allocations: allocations,
            currency: displayCurrency
        )
    }
}
