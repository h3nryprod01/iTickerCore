import Foundation

// MARK: - SearchMerge

/// Pure, Sendable, synchronous helpers for merging and ranking search results
/// across multiple asset classes. No network calls; no concurrency — fully unit-testable.
public enum SearchMerge {

    // MARK: - Rank tier

    /// Ranking tier for an instrument against a query.
    /// Lower rawValue = higher priority in the sorted list.
    private enum Tier: Int, Comparable {
        case exactSymbol     = 0  // symbol == query (case-insensitive)
        case prefixSymbol    = 1  // symbol starts with query
        case prefixName      = 2  // name starts with query
        case substringSymbol = 3  // symbol contains query
        case substringName   = 4  // name contains query
        case noMatch         = 5  // no match at all — sorted after all real matches

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    // MARK: - Public API

    /// Merge new results into an existing list, deduping by `Instrument.id`, then
    /// re-rank the full merged list against `query`.
    ///
    /// - Parameters:
    ///   - existing: Already-accumulated results from prior sources.
    ///   - incoming: New results from the latest source.
    ///   - query: The user's search string (used for re-ranking).
    /// - Returns: Deduped, ranked list. Order within the same tier is stable
    ///   (existing order is preserved for ties).
    public static func mergeSearchResults(
        existing: [Instrument],
        incoming: [Instrument],
        query: String
    ) -> [Instrument] {
        // Build a set of ids already present so we skip exact duplicates.
        var seenIDs = Set<String>(existing.map(\.id))
        let novelIncoming = incoming.filter { seenIDs.insert($0.id).inserted }
        let merged = existing + novelIncoming
        return rankSearchResults(merged, query: query)
    }

    /// Rank a flat list of instruments against `query` by tier, then stable-sort
    /// within each tier (original relative order preserved).
    ///
    /// Tier order (best → worst):
    ///   1. Exact symbol match (case-insensitive)
    ///   2. Symbol prefix match
    ///   3. Name prefix match
    ///   4. Symbol substring match
    ///   5. Name substring match
    ///
    /// Items that don't match at all are moved to the end (they can appear if `existing`
    /// was populated with a different query — callers should pass freshly filtered lists
    /// for best results, but this function handles the case gracefully).
    public static func rankSearchResults(_ instruments: [Instrument], query: String) -> [Instrument] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return instruments }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()

        // Stable sort: zip with original index to preserve relative order within ties.
        let indexed = instruments.enumerated().map { ($0.offset, $0.element) }

        let sorted = indexed.sorted { lhs, rhs in
            let lTier = tier(for: lhs.1, query: q)
            let rTier = tier(for: rhs.1, query: q)
            if lTier != rTier { return lTier < rTier }
            return lhs.0 < rhs.0   // same tier → preserve original order (stable)
        }

        return sorted.map(\.1)
    }

    // MARK: - Private

    private static func tier(for instrument: Instrument, query: String) -> Tier {
        let sym  = instrument.symbol.lowercased()
        let name = instrument.name.lowercased()

        if sym == query               { return .exactSymbol }
        if sym.hasPrefix(query)       { return .prefixSymbol }
        if name.hasPrefix(query)      { return .prefixName }
        if sym.contains(query)        { return .substringSymbol }
        if name.contains(query)       { return .substringName }
        // No match — place after all real matches.
        return .noMatch
    }
}
