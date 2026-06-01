import Foundation

// MARK: - OnboardingSeed

/// Pure helpers for personalised onboarding: preset seeding and default currency selection.
///
/// Currency rule:
///   - If `.vnEquity` is in the selected classes → `.vnd`
///   - Otherwise → `.usd`
///
/// This is a deliberate product decision: a user who explicitly opts in to VN Stocks
/// is assumed to operate in VND. They can change the currency in Settings at any time.
public enum OnboardingSeed {

    // MARK: - Preset seeding

    /// Returns the first `perClass` preset instruments for each selected asset class.
    ///
    /// - Parameters:
    ///   - classes: The set of asset classes the user selected.
    ///   - perClass: How many instruments to include per class (default 5).
    /// - Returns: A deterministic, deduplicated list of `Instrument` values.
    ///   Order follows `AssetClass.allCases` order, then the PresetCatalog order within each class.
    ///   An empty selection returns an empty array.
    public static func presets(
        forSelected classes: Set<AssetClass>,
        perClass: Int = 5
    ) -> [Instrument] {
        var result: [Instrument] = []
        var seen: Set<String> = []
        for assetClass in AssetClass.allCases where classes.contains(assetClass) {
            let slice = PresetCatalog.presets(for: assetClass).prefix(perClass)
            for instrument in slice where !seen.contains(instrument.id) {
                result.append(instrument)
                seen.insert(instrument.id)
            }
        }
        return result
    }

    // MARK: - Default currency

    /// Derives the default `DisplayCurrency` from the user's selected asset classes.
    ///
    /// Rule: `.vnd` when `.vnEquity` is selected (regardless of other selections); `.usd` otherwise.
    ///
    /// - Parameter classes: The set of asset classes the user selected (may be empty).
    /// - Returns: `.vnd` if `.vnEquity` is in `classes`; `.usd` otherwise.
    public static func defaultCurrency(forSelected classes: Set<AssetClass>) -> DisplayCurrency {
        classes.contains(.vnEquity) ? .vnd : .usd
    }
}
