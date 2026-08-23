//
//  TipJarProduct.swift
//  QuestKeeper
//
//  Spec 020 — the pure half of the tip jar: which tiers exist, and what a purchase
//  signal means. No StoreKit import, so both are testable without a store.
//

import Foundation

/// 팁 한 단계. 게임에는 아무것도 주지 않으며, 순서와 상품 식별자만 소유한다.
nonisolated enum TipJarTier: String, CaseIterable, Sendable {
    case small
    case medium
    case large

    /// App Store Connect 상품 식별자. 등록한 문자열과 정확히 일치해야 한다.
    var productID: String { "kr.donminzzi.QuestKeeper.tip.\(rawValue)" }

    /// 화면에 나열하는 순서. 낮은 금액이 먼저다.
    static var displayOrder: [TipJarTier] { allCases }

    static func tier(forProductID productID: String) -> TipJarTier? {
        allCases.first { $0.productID == productID }
    }
}

/// 구매 시도가 돌려주는 신호.
/// StoreKit의 `VerificationResult`를 그대로 올리지 않기 때문에, 테스트용 페이크가
/// 검증에 실패한 거래까지 만들어낼 수 있다.
nonisolated enum TipJarPurchaseSignal: Equatable, Sendable {
    /// 거래가 성립했다. `verified`는 JWS 서명 검증 결과다.
    case completed(verified: Bool)
    case userCancelled
    /// Ask to Buy 등으로 승인을 기다리는 상태.
    case pending
    case failed
}

/// 팁 구매 결과. 뷰는 StoreKit 타입이 아니라 이 값만 읽는다.
nonisolated enum TipJarOutcome: Equatable, Sendable {
    /// 검증된 구매. 감사 문구를 보여준다.
    case thanked
    /// 검증에 실패한 거래. 큐에서 치우되 감사하지 않는다.
    case discarded
    /// 사용자가 취소했다. 화면에 흔적을 남기지 않는다.
    case cancelled
    case pending
    case failed
}

/// 신호를 결과로 바꾸는 순수 판정.
///
/// 이 판정이 StoreKit 래퍼 안에 있으면 페이크가 검증 실패를 만들 수 없고,
/// 폐기 경로를 확인하는 테스트가 구조적으로 통과해버린다. 그래서 seam 위에 둔다.
nonisolated enum TipJarPolicy {
    static func outcome(for signal: TipJarPurchaseSignal) -> TipJarOutcome {
        switch signal {
        case .completed(verified: true): .thanked
        case .completed(verified: false): .discarded
        case .userCancelled: .cancelled
        case .pending: .pending
        case .failed: .failed
        }
    }

    /// 거래를 큐에서 치워야 하는지 판정한다.
    ///
    /// 검증에 실패한 거래는 치우지 않는다. Apple의 예제는 `.unverified`에서 곧바로 throw 해
    /// `finish()`에 닿지 않으며, 규칙은 "지급을 마친 뒤에만 finish 한다"이다. 지급하지 않을
    /// 거래를 finish 하면 사용자는 결제하고도 아무것도 받지 못한 채 되돌릴 길이 없어진다.
    /// 재전달은 그래서 생기는 낭비가 아니라 재시도 수단이다.
    static func shouldFinish(_ signal: TipJarPurchaseSignal) -> Bool {
        switch signal {
        case .completed(let verified): verified
        case .userCancelled, .pending, .failed: false
        }
    }
}
