import Testing
@testable import iTickerCore

// MARK: - ProductID Tests

@Suite("ProductID Tests")
struct ProductIDTests {

    @Test("Pro product ID has correct raw value")
    func proRawValue() {
        #expect(ProductID.pro.rawValue == "com.iticker.pro")
    }

    @Test("Tip product IDs have correct raw values")
    func tipRawValues() {
        #expect(ProductID.tipSmall.rawValue  == "com.iticker.tip.small")
        #expect(ProductID.tipMedium.rawValue == "com.iticker.tip.medium")
        #expect(ProductID.tipLarge.rawValue  == "com.iticker.tip.large")
    }

    @Test("isPro is true only for .pro")
    func isProClassification() {
        #expect(ProductID.pro.isPro       == true)
        #expect(ProductID.tipSmall.isPro  == false)
        #expect(ProductID.tipMedium.isPro == false)
        #expect(ProductID.tipLarge.isPro  == false)
    }

    @Test("isTip is true only for the three tip tiers")
    func isTipClassification() {
        #expect(ProductID.pro.isTip        == false)
        #expect(ProductID.tipSmall.isTip   == true)
        #expect(ProductID.tipMedium.isTip  == true)
        #expect(ProductID.tipLarge.isTip   == true)
    }

    @Test("allIDs contains all four product IDs")
    func allIDsCount() {
        #expect(ProductID.allIDs.count == 4)
    }

    @Test("allIDs contains the Pro ID")
    func allIDsContainsPro() {
        #expect(ProductID.allIDs.contains("com.iticker.pro"))
    }

    @Test("allIDs contains all tip IDs")
    func allIDsContainsTips() {
        #expect(ProductID.allIDs.contains("com.iticker.tip.small"))
        #expect(ProductID.allIDs.contains("com.iticker.tip.medium"))
        #expect(ProductID.allIDs.contains("com.iticker.tip.large"))
    }

    @Test("No duplicate IDs in allIDs")
    func allIDsUnique() {
        let ids = ProductID.allIDs
        #expect(Set(ids).count == ids.count)
    }

    @Test("isPro and isTip are mutually exclusive for each product")
    func mutuallyExclusive() {
        for product in ProductID.allCases {
            // A product cannot be both pro and tip
            #expect(!(product.isPro && product.isTip))
            // Every product must be one or the other
            #expect(product.isPro || product.isTip)
        }
    }

    @Test("allIDs contains exactly the 4 expected ID strings")
    func allIDsExactContent() {
        let expected: Set<String> = [
            "com.iticker.pro",
            "com.iticker.tip.small",
            "com.iticker.tip.medium",
            "com.iticker.tip.large",
        ]
        #expect(Set(ProductID.allIDs) == expected)
    }

    @Test("Round-trip: init from rawValue recovers the enum case")
    func rawValueRoundTrip() {
        #expect(ProductID(rawValue: "com.iticker.pro")        == .pro)
        #expect(ProductID(rawValue: "com.iticker.tip.small")  == .tipSmall)
        #expect(ProductID(rawValue: "com.iticker.tip.medium") == .tipMedium)
        #expect(ProductID(rawValue: "com.iticker.tip.large")  == .tipLarge)
    }

    @Test("Unknown raw value returns nil")
    func unknownRawValueIsNil() {
        #expect(ProductID(rawValue: "com.iticker.unknown") == nil)
        #expect(ProductID(rawValue: "") == nil)
    }

    @Test("Exactly 4 ProductID cases exist")
    func caseCount() {
        #expect(ProductID.allCases.count == 4)
    }

    @Test("Exactly 1 ProductID is isPro")
    func exactlyOneProID() {
        let proCount = ProductID.allCases.filter(\.isPro).count
        #expect(proCount == 1)
    }

    @Test("Exactly 3 ProductIDs are isTip")
    func exactlyThreeTipIDs() {
        let tipCount = ProductID.allCases.filter(\.isTip).count
        #expect(tipCount == 3)
    }
}

// MARK: - TipTier Tests

@Suite("TipTier Tests")
struct TipTierTests {

    @Test("Exactly 3 tip tiers")
    func tierCount() {
        #expect(TipTier.all.count == 3)
    }

    @Test("Tiers have unique product IDs")
    func uniqueIDs() {
        let ids = TipTier.all.map(\.productID)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Tiers have unique sort orders")
    func uniqueSortOrders() {
        let orders = TipTier.all.map(\.sortOrder)
        #expect(Set(orders).count == orders.count)
    }

    @Test("Tiers are ordered ascending by sortOrder")
    func ascendingOrder() {
        let orders = TipTier.all.map(\.sortOrder)
        let sorted = orders.sorted()
        #expect(orders == sorted)
    }

    @Test("All tiers use tip product IDs")
    func allAreTips() {
        for tier in TipTier.all {
            #expect(tier.productID.isTip)
        }
    }

    @Test("Tier display names are non-empty")
    func nonEmptyDisplayNames() {
        for tier in TipTier.all {
            #expect(!tier.displayName.isEmpty)
        }
    }

    @Test("Small tier is first")
    func smallIsFirst() {
        #expect(TipTier.all[0].productID == .tipSmall)
    }

    @Test("Large tier is last")
    func largeIsLast() {
        #expect(TipTier.all[2].productID == .tipLarge)
    }

    @Test("Each tier maps to its canonical tip ProductID")
    func tierProductIDMapping() {
        #expect(TipTier.all[0].productID == .tipSmall)
        #expect(TipTier.all[1].productID == .tipMedium)
        #expect(TipTier.all[2].productID == .tipLarge)
    }

    @Test("Medium tier is in the middle")
    func mediumIsMiddle() {
        #expect(TipTier.all[1].productID == .tipMedium)
    }
}
