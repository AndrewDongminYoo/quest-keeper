import Foundation
import Testing
@testable import QuestKeeper

/// 프로토콜 seam에 꽂는 페이크. StoreKit을 부르지 않으므로 검증 실패 거래까지 만들 수 있다.
@MainActor
private final class FakeTipJarStore: TipJarStore {
    var items: [TipJarItem] = []
    var loadFails = false
    var signal: TipJarPurchaseSignal = .completed(verified: true)
    private(set) var purchasedTiers: [TipJarTier] = []

    struct LoadFailure: Error {}

    func loadItems() async throws -> [TipJarItem] {
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

    @Test("an unverified transaction is still finished, or the consumable is redelivered forever")
    func unverifiedIsFinished() {
        #expect(TipJarPolicy.shouldFinish(.completed(verified: false)))
        #expect(TipJarPolicy.shouldFinish(.completed(verified: true)))
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
            TipJarItem(tier: .small, displayPrice: "₩1,100"),
            TipJarItem(tier: .medium, displayPrice: "₩3,300"),
            TipJarItem(tier: .large, displayPrice: "₩5,500"),
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

    @Test("an unverified transaction never thanks the user")
    func unverifiedPurchaseDoesNotThank() async {
        let store = FakeTipJarStore()
        store.signal = .completed(verified: false)
        let model = TipJarModel(store: store)

        await model.tip(.large)

        #expect(!model.isThanking)
    }

    @Test("cancelling leaves no state behind")
    func cancellingLeavesNothing() async {
        let store = FakeTipJarStore()
        store.signal = .userCancelled
        let model = TipJarModel(store: store)

        await model.tip(.small)

        #expect(!model.isThanking)
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

        model.dismissThanks()
        #expect(!model.isThanking)
    }
}
