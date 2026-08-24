import Foundation
import Testing
@testable import QuestKeeper

/// 프로토콜 seam에 꽂는 페이크. StoreKit을 부르지 않으므로 검증 실패 거래까지 만들 수 있다.
@MainActor
private final class FakeTipJarStore: TipJarStore {
    var items: [TipJarItem] = []
    var loadFails = false
    var loadError: Error?
    var signal: TipJarPurchaseSignal = .completed(verified: true)
    private(set) var purchasedTiers: [TipJarTier] = []

    struct LoadFailure: Error {}

    func loadItems() async throws -> [TipJarItem] {
        if let loadError { throw loadError }
        if loadFails { throw LoadFailure() }
        return items
    }

    func purchase(_ tier: TipJarTier) async -> TipJarPurchaseSignal {
        purchasedTiers.append(tier)
        return signal
    }

    func listenForTransactions() async {}
}

@Suite("Tip jar tiers")
struct TipJarTierTests {
    @Test("tiers are listed from the smallest amount upward")
    func displayOrder() {
        #expect(TipJarTier.displayOrder == [.small, .medium, .large])
    }

    @Test("product identifiers match what App Store Connect must register")
    func productIdentifiers() {
        #expect(TipJarTier.small.productID == "kr.donminzzi.QuestKeeper.tip.small")
        #expect(TipJarTier.medium.productID == "kr.donminzzi.QuestKeeper.tip.medium")
        #expect(TipJarTier.large.productID == "kr.donminzzi.QuestKeeper.tip.large")
    }

    @Test("every identifier maps back to its tier, and an unknown one maps to nothing")
    func identifierRoundTrip() {
        for tier in TipJarTier.allCases {
            #expect(TipJarTier.tier(forProductID: tier.productID) == tier)
        }
        #expect(TipJarTier.tier(forProductID: "kr.donminzzi.QuestKeeper.tip.huge") == nil)
    }
}

@Suite("Tip jar policy")
struct TipJarPolicyTests {
    @Test("a verified purchase thanks the user, an unverified one is discarded")
    func verificationDecidesTheOutcome() {
        #expect(TipJarPolicy.outcome(for: .completed(verified: true)) == .thanked)
        #expect(TipJarPolicy.outcome(for: .completed(verified: false)) == .discarded)
    }

    @Test("cancelling, pending and failure each carry their own outcome")
    func nonCompletingSignals() {
        #expect(TipJarPolicy.outcome(for: .userCancelled) == .cancelled)
        #expect(TipJarPolicy.outcome(for: .pending) == .pending)
        #expect(TipJarPolicy.outcome(for: .failed) == .failed)
    }

    @Test("only a verified transaction is finished — an unverified one stays pending for retry")
    func onlyVerifiedIsFinished() {
        #expect(TipJarPolicy.shouldFinish(.completed(verified: true)))
        #expect(!TipJarPolicy.shouldFinish(.completed(verified: false)))
    }

    @Test("a tier absent from the returned set is reported missing")
    func missingTiersAreNamed() {
        #expect(TipJarPolicy.missingTiers(returned: [.small, .medium, .large]).isEmpty)
        #expect(TipJarPolicy.missingTiers(returned: [.small, .large]) == [.medium])
        #expect(TipJarPolicy.missingTiers(returned: []) == [.small, .medium, .large])
    }

    @Test("nothing is finished when no transaction was created")
    func nonTransactionsAreNotFinished() {
        #expect(!TipJarPolicy.shouldFinish(.userCancelled))
        #expect(!TipJarPolicy.shouldFinish(.pending))
        #expect(!TipJarPolicy.shouldFinish(.failed))
    }
}

@Suite("Tip jar model")
@MainActor
struct TipJarModelTests {
    private func makeItems() -> [TipJarItem] {
        [
            TipJarItem(tier: .small, displayName: "물약 한 병", displayPrice: "₩1,100"),
            TipJarItem(tier: .medium, displayName: "물약 세 병", displayPrice: "₩3,300"),
            TipJarItem(tier: .large, displayName: "물약 한 상자", displayPrice: "₩5,500"),
        ]
    }

    @Test("a successful load carries the store's items through")
    func loadSucceeds() async {
        let store = FakeTipJarStore()
        store.items = makeItems()
        let model = TipJarModel(store: store)

        await model.load()

        #expect(model.loadState == .loaded(makeItems()))
    }

    @Test("a failed load reaches the retry state rather than throwing")
    func loadFails() async {
        let store = FakeTipJarStore()
        store.loadFails = true
        let model = TipJarModel(store: store)

        await model.load()

        #expect(model.loadState == .failed)
    }

    @Test("a verified purchase reaches the thank-you state")
    func verifiedPurchaseThanks() async {
        let store = FakeTipJarStore()
        store.signal = .completed(verified: true)
        let model = TipJarModel(store: store)

        await model.tip(.medium)

        #expect(model.isThanking)
        #expect(store.purchasedTiers == [.medium])
        #expect(model.purchasingTier == nil)
    }

    @Test("an unverified transaction never thanks the user, and says the payment did not land")
    func unverifiedPurchaseDoesNotThank() async {
        let store = FakeTipJarStore()
        store.signal = .completed(verified: false)
        let model = TipJarModel(store: store)

        await model.tip(.large)

        #expect(!model.isThanking)
        #expect(model.purchaseNote == .failed)
    }

    @Test("a failed purchase is surfaced rather than silently reset")
    func failureIsSurfaced() async {
        let store = FakeTipJarStore()
        store.signal = .failed
        let model = TipJarModel(store: store)

        await model.tip(.small)

        #expect(model.purchaseNote == .failed)
        #expect(!model.isThanking)
    }

    @Test("an incomplete catalog reaches the retry state rather than a partial list")
    func incompleteCatalogFails() async {
        let store = FakeTipJarStore()
        // 페이크가 프로덕션과 같은 오류를 던진다. loadFails 로 다른 오류를 강제하면
        // 완전성 검사를 지워도 초록으로 남는 테스트가 된다.
        store.loadError = TipJarLoadError.incompleteCatalog(missing: [.medium])
        let model = TipJarModel(store: store)

        await model.load()

        #expect(model.loadState == .failed)
    }

    @Test("cancelling leaves no state behind")
    func cancellingLeavesNothing() async {
        let store = FakeTipJarStore()
        store.signal = .userCancelled
        let model = TipJarModel(store: store)

        await model.tip(.small)

        #expect(!model.isThanking)
        #expect(model.purchaseNote == .none)
        #expect(model.purchasingTier == nil)
    }

    @Test("a pending approval does not thank the user either")
    func pendingDoesNotThank() async {
        let store = FakeTipJarStore()
        store.signal = .pending
        let model = TipJarModel(store: store)

        await model.tip(.small)

        #expect(!model.isThanking)
    }

    @Test("the thank-you state can be dismissed")
    func thanksDismisses() async {
        let store = FakeTipJarStore()
        let model = TipJarModel(store: store)

        await model.tip(.small)
        #expect(model.isThanking)

        model.dismissNote()
        #expect(!model.isThanking)
    }
}
