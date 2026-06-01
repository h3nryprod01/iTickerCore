import Testing
@testable import iTickerCore

@Suite("ProGate Tests")
struct ProGateTests {

    // MARK: - alwaysAvailable policy

    @Test("alwaysAvailable: free user can access feature")
    func alwaysAvailableForFreeUser() {
        let gate = ProGate(policy: [.exchangeSync: .alwaysAvailable])
        #expect(gate.isEnabled(.exchangeSync, isPro: false) == true)
    }

    @Test("alwaysAvailable: Pro user can access feature")
    func alwaysAvailableForProUser() {
        let gate = ProGate(policy: [.exchangeSync: .alwaysAvailable])
        #expect(gate.isEnabled(.exchangeSync, isPro: true) == true)
    }

    @Test("alwaysAvailable: unlimitedAlerts free user")
    func alwaysAvailableAlertsFreUser() {
        let gate = ProGate(policy: [.unlimitedAlerts: .alwaysAvailable])
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == true)
    }

    @Test("alwaysAvailable: unlimitedAlerts Pro user")
    func alwaysAvailableAlertsProUser() {
        let gate = ProGate(policy: [.unlimitedAlerts: .alwaysAvailable])
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true) == true)
    }

    // MARK: - requiresPro policy

    @Test("requiresPro: free user cannot access feature")
    func requiresProBlocksFreeUser() {
        let gate = ProGate(policy: [.exchangeSync: .requiresPro])
        #expect(gate.isEnabled(.exchangeSync, isPro: false) == false)
    }

    @Test("requiresPro: Pro user can access feature")
    func requiresProAllowsProUser() {
        let gate = ProGate(policy: [.exchangeSync: .requiresPro])
        #expect(gate.isEnabled(.exchangeSync, isPro: true) == true)
    }

    @Test("requiresPro mirrors isPro exactly")
    func requiresProMirrorsIsPro() {
        let gate = ProGate(policy: [.unlimitedAlerts: .requiresPro])
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == false)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true)  == true)
    }

    // MARK: - Missing policy key defaults to alwaysAvailable

    @Test("Missing policy key defaults to alwaysAvailable for free user")
    func missingKeyDefaultsFreeUser() {
        let gate = ProGate(policy: [:]) // empty — no policies set
        #expect(gate.isEnabled(.exchangeSync, isPro: false) == true)
    }

    @Test("Missing policy key defaults to alwaysAvailable for Pro user")
    func missingKeyDefaultsProUser() {
        let gate = ProGate(policy: [:])
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true) == true)
    }

    // MARK: - Default static instance (free-first)

    @Test("Default ProGate is free-first: all features pass for free users")
    func defaultGateFreeFirst() {
        let gate = ProGate.default
        for feature in ProFeature.allCases {
            #expect(gate.isEnabled(feature, isPro: false) == true)
        }
    }

    @Test("Default ProGate: Pro users also have access")
    func defaultGateProUsers() {
        let gate = ProGate.default
        for feature in ProFeature.allCases {
            #expect(gate.isEnabled(feature, isPro: true) == true)
        }
    }

    // MARK: - Compound: multiple features, mixed policies

    @Test("Mixed policies: one gated, one free")
    func mixedPolicies() {
        let gate = ProGate(policy: [
            .exchangeSync:    .requiresPro,
            .unlimitedAlerts: .alwaysAvailable,
        ])
        // Free user: only the alwaysAvailable feature is accessible
        #expect(gate.isEnabled(.exchangeSync,    isPro: false) == false)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == true)

        // Pro user: both features accessible
        #expect(gate.isEnabled(.exchangeSync,    isPro: true) == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true) == true)
    }

    // MARK: - Default policy is explicitly alwaysAvailable for every known feature

    @Test("defaultPolicy contains alwaysAvailable for exchangeSync — free-first guarantee")
    func defaultPolicyExchangeSyncIsAlwaysAvailable() {
        #expect(ProGate.defaultPolicy[.exchangeSync] == .alwaysAvailable)
    }

    @Test("defaultPolicy contains alwaysAvailable for unlimitedAlerts — free-first guarantee")
    func defaultPolicyUnlimitedAlertsIsAlwaysAvailable() {
        #expect(ProGate.defaultPolicy[.unlimitedAlerts] == .alwaysAvailable)
    }

    @Test("defaultPolicy covers all ProFeature cases — no feature accidentally ungated")
    func defaultPolicyCoversAllFeatures() {
        for feature in ProFeature.allCases {
            #expect(ProGate.defaultPolicy[feature] != nil,
                    "defaultPolicy missing entry for \(feature); add .alwaysAvailable explicitly")
        }
    }

    // MARK: - Full truth table: BOTH features × BOTH policies × BOTH isPro values

    @Test("Full truth table: alwaysAvailable × {free, Pro} returns true for both features")
    func fullTruthTableAlwaysAvailable() {
        let gate = ProGate(policy: [
            .exchangeSync:    .alwaysAvailable,
            .unlimitedAlerts: .alwaysAvailable,
        ])
        // Row: alwaysAvailable, free user
        #expect(gate.isEnabled(.exchangeSync,    isPro: false) == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == true)
        // Row: alwaysAvailable, Pro user
        #expect(gate.isEnabled(.exchangeSync,    isPro: true)  == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true)  == true)
    }

    @Test("Full truth table: requiresPro × {free, Pro} mirrors isPro for both features")
    func fullTruthTableRequiresPro() {
        let gate = ProGate(policy: [
            .exchangeSync:    .requiresPro,
            .unlimitedAlerts: .requiresPro,
        ])
        // Row: requiresPro, free user — blocked
        #expect(gate.isEnabled(.exchangeSync,    isPro: false) == false)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == false)
        // Row: requiresPro, Pro user — allowed
        #expect(gate.isEnabled(.exchangeSync,    isPro: true)  == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true)  == true)
    }

    // MARK: - Flip-to-Pro mechanism (proves the one-line-change works)

    @Test("Flipping exchangeSync to requiresPro gates free users without changing unlimitedAlerts")
    func flipExchangeSyncToRequiresPro() {
        // Simulate the one-line config change: exchangeSync -> .requiresPro
        let gate = ProGate(policy: [
            .exchangeSync:    .requiresPro,     // flipped
            .unlimitedAlerts: .alwaysAvailable, // unchanged
        ])
        // Free user: exchangeSync now blocked; unlimitedAlerts still free
        #expect(gate.isEnabled(.exchangeSync,    isPro: false) == false)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == true)
        // Pro user: both accessible
        #expect(gate.isEnabled(.exchangeSync,    isPro: true)  == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true)  == true)
    }

    @Test("Flipping unlimitedAlerts to requiresPro gates free users without changing exchangeSync")
    func flipUnlimitedAlertsToRequiresPro() {
        // Simulate the one-line config change: unlimitedAlerts -> .requiresPro
        let gate = ProGate(policy: [
            .exchangeSync:    .alwaysAvailable, // unchanged
            .unlimitedAlerts: .requiresPro,     // flipped
        ])
        // Free user: unlimitedAlerts now blocked; exchangeSync still free
        #expect(gate.isEnabled(.exchangeSync,    isPro: false) == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == false)
        // Pro user: both accessible
        #expect(gate.isEnabled(.exchangeSync,    isPro: true)  == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true)  == true)
    }

    @Test("Flipping both features to requiresPro — full Pro enforcement scenario")
    func flipBothToRequiresPro() {
        let gate = ProGate(policy: [
            .exchangeSync:    .requiresPro,
            .unlimitedAlerts: .requiresPro,
        ])
        // Free user locked out of both
        #expect(gate.isEnabled(.exchangeSync,    isPro: false) == false)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: false) == false)
        // Pro user has everything
        #expect(gate.isEnabled(.exchangeSync,    isPro: true)  == true)
        #expect(gate.isEnabled(.unlimitedAlerts, isPro: true)  == true)
    }

    // MARK: - ProGate.default is the zero-configuration free-first instance

    @Test("ProGate.default uses defaultPolicy (same reference semantics)")
    func defaultInstanceUsesDefaultPolicy() {
        let gate = ProGate.default
        // The default gate must pass every feature for every isPro value
        // because defaultPolicy sets alwaysAvailable for all known features
        for feature in ProFeature.allCases {
            #expect(gate.isEnabled(feature, isPro: false) == true,
                    "Default gate blocked free user for \(feature)")
            #expect(gate.isEnabled(feature, isPro: true)  == true,
                    "Default gate blocked Pro user for \(feature)")
        }
    }
}
