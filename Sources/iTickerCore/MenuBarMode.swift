import Foundation

// MARK: - MenuBarMode

/// Which data source the macOS menu-bar label and dropdown show.
public enum MenuBarMode: String, Codable, Sendable, CaseIterable {
    /// Rotate through all watchlist items (default).
    case watchlist = "watchlist"
    /// Show portfolio total value + day P/L% (manual holdings only).
    case portfolio = "portfolio"
    /// Rotate through a user-selected subset of tickers.
    case selected  = "selected"
}

// MARK: - MenuBarSource

/// Pure helpers for determining which instrument IDs the menu bar should display,
/// given the current mode and the user's data. Tested headlessly in iTickerCoreTests.
public enum MenuBarSource {

    /// Returns the ordered list of instrument IDs to rotate/display.
    ///
    /// - Parameters:
    ///   - mode: The current `MenuBarMode`.
    ///   - watchIDs: Sorted instrument IDs from the user's watchlist.
    ///   - holdingIDs: Sorted instrument IDs from the user's manual holdings.
    ///   - selectedIDs: Sorted instrument IDs the user explicitly picked for `.selected` mode.
    /// - Returns: A stable-ordered array of IDs. Empty when the source has no items.
    public static func idsToDisplay(
        mode: MenuBarMode,
        watchIDs: [String],
        holdingIDs: [String],
        selectedIDs: [String]
    ) -> [String] {
        switch mode {
        case .watchlist: return watchIDs
        case .portfolio: return holdingIDs
        case .selected:  return selectedIDs
        }
    }
}

// MARK: - MenuBarLabelBuilder

/// Pure string-builder for the portfolio menu-bar label.
/// Produces a compact human-readable label such as "$12,345 +1.2%".
public enum MenuBarLabelBuilder {

    /// Build a compact portfolio label string.
    ///
    /// Format:
    ///   - Positive P/L: "$12,345 +1.23%"
    ///   - Negative P/L: "$12,345 -0.45%"
    ///   - Zero P/L:     "$12,345 0.00%"
    ///   - VND mode:     "₫12,345,678 +1.23%"
    ///
    /// Returns `nil` when `totalValue` is zero (no holdings with quotes).
    public static func portfolioLabel(
        totalValue: Double,
        totalUnrealizedPLPct: Double,
        currency: DisplayCurrency
    ) -> String? {
        guard totalValue > 0 else { return nil }
        let valueStr = formatCompact(totalValue, currency: currency)
        let sign = totalUnrealizedPLPct >= 0 ? "+" : ""
        let pctStr = "\(sign)\(String(format: "%.2f", totalUnrealizedPLPct))%"
        return "\(valueStr) \(pctStr)"
    }

    // MARK: - Private

    private static func formatCompact(_ value: Double, currency: DisplayCurrency) -> String {
        switch currency {
        case .usd:
            return usdCompactFormatter.string(from: NSNumber(value: value))
                ?? String(format: "$%.0f", value)
        case .vnd:
            return vndCompactFormatter.string(from: NSNumber(value: value))
                ?? String(format: "\u{20AB}%.0f", value)
        }
    }
}

// MARK: - Package-private formatters

private let usdCompactFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.currencySymbol = "$"
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 0
    f.usesGroupingSeparator = true
    return f
}()

private let vndCompactFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "VND"
    f.currencySymbol = "\u{20AB}"
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 0
    f.usesGroupingSeparator = true
    return f
}()
