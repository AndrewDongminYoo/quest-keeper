//
//  TipJarModel.swift
//  QuestKeeper
//
//  Spec 020 — the state the About sheet renders from. Holds a TipJarStore behind the
//  protocol seam, so a fake drives every case in the test suite.
//

import Foundation
import Observation

@MainActor
@Observable
final class TipJarModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([TipJarItem])
        /// 상품을 불러오지 못했다. 시트의 나머지는 그대로 두고 재시도만 제안한다.
        case failed
    }

    private(set) var loadState: LoadState = .idle
    /// 검증된 구매 직후에만 참이다. 취소나 검증 실패는 여기에 닿지 않는다.
    private(set) var isThanking = false
    private(set) var purchasingTier: TipJarTier?

    private let store: TipJarStore

    init(store: TipJarStore) {
        self.store = store
    }

    func load() async {
        loadState = .loading
        do {
            loadState = .loaded(try await store.loadItems())
        } catch {
            loadState = .failed
        }
    }

    func tip(_ tier: TipJarTier) async {
        purchasingTier = tier
        defer { purchasingTier = nil }

        // 검증 판정은 seam 위의 순수 함수가 한다 — 그래야 페이크가 검증 실패까지 만든다.
        let outcome = TipJarPolicy.outcome(for: await store.purchase(tier))

        // 감사 문구는 검증된 구매에만 뜬다.
        // 취소는 화면에 아무 흔적도 남기지 않는다 — 되묻거나 아쉬워하지 않는다.
        if outcome == .thanked {
            isThanking = true
        }
    }

    func dismissThanks() {
        isThanking = false
    }
}
