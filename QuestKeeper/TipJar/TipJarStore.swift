//
//  TipJarStore.swift
//  QuestKeeper
//
//  Spec 020 — the StoreKit side effect. The protocol is the test seam; inject a fake
//  rather than reaching for StoreKit in a unit test, exactly as QuestNotificationCenter does.
//

import Foundation
import StoreKit
import os

private let tipJarLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "QuestKeeper",
    category: "TipJar"
)

/// 화면에 뿌릴 팁 한 줄.
/// 가격 문자열은 StoreKit이 지역화한 `displayPrice`를 그대로 옮기며, 통화 문자열을
/// 코드나 문자열 카탈로그에 적지 않는다.
nonisolated struct TipJarItem: Equatable, Sendable, Identifiable {
    let tier: TipJarTier
    /// StoreKit 이 준 상품 이름. 티어마다 달라야 세 줄을 구분할 수 있다.
    let displayName: String
    let displayPrice: String

    var id: TipJarTier { tier }
}

@MainActor
protocol TipJarStore: AnyObject {
    func loadItems() async throws -> [TipJarItem]
    func purchase(_ tier: TipJarTier) async -> TipJarPurchaseSignal
    /// 프로세스가 살아 있는 동안 유지되는 거래 리스너.
    /// 구매 호출 밖에서 도착하는 거래(Ask to Buy 승인, 중단된 구매)를 받아 정리한다.
    func listenForTransactions() async
}

@MainActor
final class StoreKitTipJarStore: TipJarStore {
    private var cachedProducts: [String: Product] = [:]

    func loadItems() async throws -> [TipJarItem] {
        let products = try await Product.products(for: TipJarTier.displayOrder.map(\.productID))
        cachedProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        // StoreKit은 요청한 순서를 보장하지 않으므로 표시 순서로 다시 세운다.
        // 등록되지 않은 티어는 조용히 빠진다 — 화면은 남은 티어로 계속 동작한다.
        return TipJarTier.displayOrder.compactMap { tier in
            cachedProducts[tier.productID].map {
                TipJarItem(tier: tier, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
        }
    }

    func purchase(_ tier: TipJarTier) async -> TipJarPurchaseSignal {
        guard let product = await product(for: tier) else { return .failed }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                return await settle(verification)
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            tipJarLogger.error("tip purchase failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    func listenForTransactions() async {
        for await verification in Transaction.updates {
            _ = await settle(verification)
        }
    }

    private func product(for tier: TipJarTier) async -> Product? {
        if let cached = cachedProducts[tier.productID] { return cached }
        _ = try? await loadItems()
        return cachedProducts[tier.productID]
    }

    /// 검증 결과를 신호로 바꾸고, 치워야 하는 거래를 큐에서 제거한다.
    /// 검증에 실패한 거래도 finish 한다 — 그러지 않으면 소모품이 무한히 재전달된다.
    private func settle(_ verification: VerificationResult<Transaction>) async -> TipJarPurchaseSignal {
        let signal: TipJarPurchaseSignal
        let transaction: Transaction

        switch verification {
        case .verified(let value):
            signal = .completed(verified: true)
            transaction = value
        case .unverified(let value, let error):
            tipJarLogger.error("unverified tip transaction: \(error.localizedDescription, privacy: .public)")
            signal = .completed(verified: false)
            transaction = value
        }

        if TipJarPolicy.shouldFinish(signal) {
            await transaction.finish()
        }
        return signal
    }
}
