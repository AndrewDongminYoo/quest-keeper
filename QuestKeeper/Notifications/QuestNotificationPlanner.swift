//
//  QuestNotificationPlanner.swift
//  QuestKeeper
//
//  Phase 3 — pure notification planning over stored facts + now.
//

import Foundation

nonisolated enum QuestNotificationPlanner {
    /// iOS keeps at most this many pending local notifications per app and discards the rest —
    /// `UNUserNotificationCenter.add` reports nothing when it happens. Which ones survive is not
    /// something to rely on, so the app picks: soonest first, since a request that fires later is
    /// the one worth losing (and the next reconcile re-adds it once it becomes near).
    static let maximumScheduledNotifications = 64

    static func identifiers(for questID: UUID) -> [String] {
        QuestNotificationKind.allCases.map { $0.identifier(for: questID) }
    }

    static func isQuestNotificationIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(QuestNotificationKind.identifierPrefix)
    }

    /// The whole desired pending set, ordered by fire date and capped.
    ///
    /// The per-quest overload emits due-soon then deadline, so concatenating it across quests does
    /// NOT yield a fire-date order even when the quests themselves are sorted by deadline — one
    /// quest's deadline lands ahead of a nearer quest's due-soon. Sorting here makes the cap cut the
    /// furthest-firing requests rather than whatever the caller's order happened to put last.
    static func plans(
        for snapshots: [QuestSnapshot],
        now: Date,
        locale: Locale = .current
    ) -> [QuestNotificationPlan] {
        let all = snapshots.flatMap { plans(for: $0, now: now, locale: locale) }
        let ordered = all.sorted(by: firesEarlier)
        return Array(ordered.prefix(maximumScheduledNotifications))
    }

    /// Total order over the desired set. Ties break on the identifier so the cap stays deterministic
    /// when two requests share a fire date. A named function rather than an inline closure — the
    /// ternary form inside `sorted(by:)` blew past the type checker's budget.
    private static func firesEarlier(
        _ lhs: QuestNotificationPlan,
        _ rhs: QuestNotificationPlan
    ) -> Bool {
        if lhs.fireDate != rhs.fireDate {
            return lhs.fireDate < rhs.fireDate
        }
        return lhs.identifier < rhs.identifier
    }

    static func plans(for snapshot: QuestSnapshot, now: Date, locale: Locale = .current) -> [QuestNotificationPlan] {
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
                    title: AppStrings.resolve(AppStrings.notificationDueSoonTitle, locale: locale),
                    body: AppStrings.resolve(AppStrings.notificationDueSoonBody, locale: locale)
                )
            )
        }

        plans.append(
            QuestNotificationPlan(
                identifier: QuestNotificationKind.deadline.identifier(for: snapshot.id),
                questID: snapshot.id,
                kind: .deadline,
                fireDate: snapshot.deadline,
                title: AppStrings.resolve(AppStrings.notificationDeadlineTitle, locale: locale),
                body: AppStrings.resolve(AppStrings.notificationDeadlineBody, locale: locale)
            )
        )

        return plans
    }
}
