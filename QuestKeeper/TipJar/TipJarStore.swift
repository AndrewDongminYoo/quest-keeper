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

nonisolated enum TipJarLoadError: Error, Equatable {
    /// 요청한 티어 중 일부가 돌아오지 않았다. 부분 목록을 성공으로 그리지 않기 위한 신호다.
    case incompleteCatalog(missing: [TipJarTier])
}

@MainActor
protocol TipJarStore: AnyObject {
    /// 구매 호출 밖에서 완료된 거래 결과. 각 구독은 독립된 스트림을 받아 시트를 다시 열어도 이어진다.
    var outcomes: AsyncStream<TipJarOutcome> { get }
    func loadItems() async throws -> [TipJarItem]
    func purchase(_ tier: TipJarTier) async -> TipJarPurchaseSignal
    /// 프로세스가 살아 있는 동안 유지되는 거래 리스너.
    /// 구매 호출 밖에서 도착하는 거래(Ask to Buy 승인, 중단된 구매)를 받아 정리한다.
    func listenForTransactions() async
}

@MainActor
final class StoreKitTipJarStore: TipJarStore {
    private var cachedProducts: [String: Product] = [:]
    private var outcomeContinuations: [UUID: AsyncStream<TipJarOutcome>.Continuation] = [:]

    var outcomes: AsyncStream<TipJarOutcome> {
        let subscriptionID = UUID()
        let pair = AsyncStream<TipJarOutcome>.makeStream()
        outcomeContinuations[subscriptionID] = pair.continuation
        pair.continuation.onTermination = { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.outcomeContinuations.removeValue(forKey: subscriptionID)
            }
        }
        return pair.stream
    }

    func loadItems() async throws -> [TipJarItem] {
        let products = try await Product.products(for: TipJarTier.displayOrder.map(\.productID))
        cachedProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        // StoreKit은 요청한 순서를 보장하지 않으므로 표시 순서로 다시 세운다.
        // 일부만 돌아오면 성공으로 다루지 않는다. 스토어프론트 미제공이나 App Store Connect
        // 전파 지연으로 한 티어가 빠지면, 조용히 두 줄만 그리는 대신 재시도를 제안해야 한다.
        // (2026-08-24에 실제로 겪었다 — medium 미등록 상태에서 오류 없이 두 줄만 떴다.)
        let items = TipJarTier.displayOrder.compactMap { tier in
            cachedProducts[tier.productID].map {
                TipJarItem(tier: tier, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
        }
        let missing = TipJarPolicy.missingTiers(returned: items.map(\.tier))
        guard missing.isEmpty else {
            tipJarLogger.error("tip products missing: \(missing.map(\.rawValue).joined(separator: ","), privacy: .public)")
            throw TipJarLoadError.incompleteCatalog(missing: missing)
        }
        return items
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
            let signal = await settle(verification)
            publish(TipJarPolicy.outcome(for: signal))
        }
    }

    private func publish(_ outcome: TipJarOutcome) {
        for continuation in outcomeContinuations.values {
            continuation.yield(outcome)
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
