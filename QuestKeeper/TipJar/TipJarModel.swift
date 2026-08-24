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

    /// 구매 시도가 화면에 남기는 흔적.
    enum PurchaseNote: Equatable {
        case none
        /// 검증된 구매. 감사 문구를 보여준다.
        case thanks
        /// 결제가 성립하지 못했거나 검증에 실패했다. 사용자는 다시 시도할지 알아야 한다.
        case failed
        /// Ask to Buy 등으로 승인을 기다린다. 이 표시가 없으면 방금 누른 항목이
        /// 아무 일도 없었던 것처럼 보여, 사용자가 다시 결제를 시도하게 된다.
        case awaitingApproval
    }

    private(set) var loadState: LoadState = .idle
    private(set) var purchaseNote: PurchaseNote = .none
    private(set) var purchasingTier: TipJarTier?

    var isThanking: Bool { purchaseNote == .thanks }

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
        apply(TipJarPolicy.outcome(for: await store.purchase(tier)))
    }

    func listenForOutcomes() async {
        for await outcome in store.outcomes {
            apply(outcome)
        }
    }

    private func apply(_ outcome: TipJarOutcome) {
        switch outcome {
        case .thanked:
            purchaseNote = .thanks
        case .failed, .discarded:
            // 결제를 시도했는데 성립하지 않았다면 알려야 한다. 그러지 않으면 진행 표시만
            // 사라지고 사용자는 결제가 됐는지조차 알 수 없다.
            purchaseNote = .failed
        case .pending:
            // 승인 결과는 나중에 리스너로 도착한다. 그때까지 대기 중임을 보여준다.
            purchaseNote = .awaitingApproval
        case .cancelled:
            // 취소는 화면에 아무 흔적도 남기지 않는다 — 되묻거나 아쉬워하지 않는다.
            purchaseNote = .none
        }
    }

    func dismissNote() {
        purchaseNote = .none
    }
}
