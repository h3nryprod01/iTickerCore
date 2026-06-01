// MARK: - ProductID

/// The concrete StoreKit product identifiers used by iTicker.
public enum ProductID: String, CaseIterable, Sendable {
    case pro           = "com.iticker.pro"
    case tipSmall      = "com.iticker.tip.small"
    case tipMedium     = "com.iticker.tip.medium"
    case tipLarge      = "com.iticker.tip.large"

    /// Returns true when this product is the lifetime Pro unlock (non-consumable).
    public var isPro: Bool { self == .pro }

    /// Returns true when this product is a consumable tip.
    public var isTip: Bool {
        switch self {
        case .tipSmall, .tipMedium, .tipLarge: return true
        case .pro: return false
        }
    }

    /// All raw product ID strings to pass to `Product.products(for:)`.
    public static var allIDs: [String] { allCases.map(\.rawValue) }
}

// MARK: - TipTier

/// A value type describing one of the three consumable tip tiers.
public struct TipTier: Equatable, Sendable {
    public let productID: ProductID
    public let displayName: String
    /// Lower number = cheaper / shown first.
    public let sortOrder: Int

    public init(productID: ProductID, displayName: String, sortOrder: Int) {
        self.productID = productID
        self.displayName = displayName
        self.sortOrder = sortOrder
    }
}

extension TipTier {
    /// The canonical ordered list of tip tiers, cheapest first.
    public static let all: [TipTier] = [
        TipTier(productID: .tipSmall,  displayName: "Small tip – $0.99",  sortOrder: 0),
        TipTier(productID: .tipMedium, displayName: "Medium tip – $2.99", sortOrder: 1),
        TipTier(productID: .tipLarge,  displayName: "Large tip – $9.99",  sortOrder: 2),
    ]
}

// MARK: - ProGate

/// Features that can be gated behind iTicker Pro.
public enum ProFeature: CaseIterable, Sendable {
    /// Binance read-only exchange sync.
    case exchangeSync
    /// Ability to create an unlimited number of price alerts.
    case unlimitedAlerts
}

/// Per-feature availability policy.
public enum FeaturePolicy: Sendable {
    /// Feature is available to all users regardless of Pro status.
    case alwaysAvailable
    /// Feature requires an active Pro entitlement.
    case requiresPro
}

/// Single source of truth for Pro feature policies.
///
/// **Free-first rollout**: every feature is `.alwaysAvailable` today.
/// To enforce a feature, change its policy to `.requiresPro` — that is a
/// one-line edit in the `defaultPolicy` dictionary below.
public struct ProGate: Sendable {

    public let policy: [ProFeature: FeaturePolicy]

    public init(policy: [ProFeature: FeaturePolicy] = ProGate.defaultPolicy) {
        self.policy = policy
    }

    /// Returns `true` when the feature is usable given the user's Pro status.
    public func isEnabled(_ feature: ProFeature, isPro: Bool) -> Bool {
        switch policy[feature] ?? .alwaysAvailable {
        case .alwaysAvailable: return true
        case .requiresPro:     return isPro
        }
    }
}

extension ProGate {
    /// The canonical default policy. Change a single line here to enforce a feature.
    public static let defaultPolicy: [ProFeature: FeaturePolicy] = [
        .exchangeSync:    .alwaysAvailable, // FREE-FIRST: flip to .requiresPro to enforce
        .unlimitedAlerts: .alwaysAvailable, // FREE-FIRST: flip to .requiresPro to enforce
    ]

    /// Convenience instance using the default free-first policy.
    public static let `default` = ProGate()
}
