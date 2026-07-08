//
//  QuestNotificationPlanner.swift
//  QuestKeeper
//
//  Phase 3 — pure notification planning over stored facts + now.
//

import Foundation

nonisolated enum QuestNotificationPlanner {
    static func identifiers(for questID: UUID) -> [String] {
        QuestNotificationKind.allCases.map { $0.identifier(for: questID) }
    }

    static func isQuestNotificationIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(QuestNotificationKind.identifierPrefix)
    }

    static func plans(for snapshot: QuestSnapshot, title: String, now: Date) -> [QuestNotificationPlan] {
        guard snapshot.completedAt == nil, snapshot.deadline > now else { return [] }

        let dueSoonDate = snapshot.deadline.addingTimeInterval(-GameBalance.notificationLeadTime)
        var plans: [QuestNotificationPlan] = []

        if dueSoonDate > now {
            plans.append(
                QuestNotificationPlan(
                    identifier: QuestNotificationKind.dueSoon.identifier(for: snapshot.id),
                    questID: snapshot.id,
                    kind: .dueSoon,
                    fireDate: dueSoonDate,
                    title: "퀘스트 마감 임박",
                    body: "\(title) · 곧 마감됩니다"
                )
            )
        }

        plans.append(
            QuestNotificationPlan(
                identifier: QuestNotificationKind.deadline.identifier(for: snapshot.id),
                questID: snapshot.id,
                kind: .deadline,
                fireDate: snapshot.deadline,
                title: "퀘스트 마감",
                body: "\(title) 마감 시간이 되었습니다"
            )
        )

        return plans
    }
}
