//
//  DebugFixtureSeeder.swift
//  QuestKeeper
//
//  UI-test and store-screenshot fixtures, kept out of `QuestKeeperApp.init` so app bootstrap
//  (container, dependencies, experiment enrolment) stays readable. Debug-only by construction:
//  the whole file compiles away in Release, so no fixture can reach a shipped build.
//

#if DEBUG
import Foundation
import SwiftData

enum DebugFixtureSeeder {
    nonisolated static func shouldSeedDailyFocusGraveFixture(
        usesUITestingStore: Bool,
        arguments: [String]
    ) -> Bool {
        usesUITestingStore && arguments.contains("-uiTestingDailyFocusGrave")
    }

    nonisolated static func shouldSeedDetailDeadlineTransitionFixture(
        usesUITestingStore: Bool,
        arguments: [String]
    ) -> Bool {
        usesUITestingStore && arguments.contains("-uiTestingDetailDeadlineTransition")
    }

    nonisolated static func shouldSeedRecoveryFixture(
        usesUITestingStore: Bool,
        arguments: [String]
    ) -> Bool {
        usesUITestingStore && arguments.contains("-uiTestingRecoveryFixture")
    }

    nonisolated static func shouldSeedHallOfFameFixture(
        usesUITestingStore: Bool,
        arguments: [String]
    ) -> Bool {
        usesUITestingStore && arguments.contains("-uiTestingHallOfFameFixture")
    }

    nonisolated static func shouldSeedCreationFactFixture(
        usesUITestingStore: Bool,
        arguments: [String]
    ) -> Bool {
        usesUITestingStore && arguments.contains("-uiTestingCreationFactWithoutQuest")
    }

    nonisolated static func shouldSeedRoutineFixture(
        usesUITestingStore: Bool,
        arguments: [String]
    ) -> Bool {
        usesUITestingStore && arguments.contains("-uiTestingRoutineFixture")
    }

    nonisolated static func shouldSeedWeeklyReviewFixture(
        usesUITestingStore: Bool,
        arguments: [String]
    ) -> Bool {
        usesUITestingStore && arguments.contains("-uiTestingWeeklyReviewFixture")
    }

    /// Seeds whichever fixture the launch arguments ask for. Each fixture is inert unless its own
    /// flag is present, and the quest-inserting ones only run against an empty store so a re-launch
    /// against a persistent UI-testing store does not stack duplicates.
    static func seed(
        into container: ModelContainer,
        arguments: [String],
        usesUITestingStore: Bool,
        usesInMemoryStore: Bool
    ) throws {
        let context = container.mainContext

        if shouldSeedDailyFocusGraveFixture(usesUITestingStore: usesUITestingStore, arguments: arguments),
           try context.fetchCount(FetchDescriptor<Quest>()) == 0 {
            context.insert(Quest(
                title: AppStrings.resolve(AppStrings.debugFixtureDailyFocusGraveTitle, locale: .current),
                deadline: Date.now.addingTimeInterval(-60),
                importance: .medium
            ))
            try context.save()
        }

        if shouldSeedDetailDeadlineTransitionFixture(usesUITestingStore: usesUITestingStore, arguments: arguments),
           try context.fetchCount(FetchDescriptor<Quest>()) == 0 {
            context.insert(Quest(
                title: "Deadline transition UI test",
                deadline: Date.now.addingTimeInterval(30),
                importance: .medium
            ))
            try context.save()
        }

        if usesInMemoryStore, arguments.contains("-storeScreenshotFixture") {
            try seedStoreScreenshotFixture(in: context)
        }

        if shouldSeedHallOfFameFixture(usesUITestingStore: usesUITestingStore, arguments: arguments),
           try context.fetchCount(FetchDescriptor<Quest>()) == 0 {
            try seedHallOfFameFixture(in: context)
        }

        if shouldSeedRoutineFixture(usesUITestingStore: usesUITestingStore, arguments: arguments),
           try context.fetchCount(FetchDescriptor<RoutineRule>()) == 0 {
            try seedRoutineFixture(in: context)
        }

        if shouldSeedWeeklyReviewFixture(usesUITestingStore: usesUITestingStore, arguments: arguments),
           try context.fetchCount(FetchDescriptor<Quest>()) == 0 {
            try seedWeeklyReviewFixture(in: context)
        }

        // 퀘스트를 만들었다가 전부 지운 뒤의 사실 상태다. 게이트가 읽는 `quest_created`를
        // 프로덕션과 같은 기록 경로로 남기므로, 픽스처가 자기 사정으로 상태를 꾸며내지 않는다.
        if shouldSeedCreationFactFixture(usesUITestingStore: usesUITestingStore, arguments: arguments),
           try context.fetchCount(FetchDescriptor<Quest>()) == 0 {
            _ = RetentionEventRecorder.recordQuestCreated(
                questID: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
                at: Date.now.addingTimeInterval(-3_600),
                in: context
            )
            try context.save()
        }

        if shouldSeedRecoveryFixture(usesUITestingStore: usesUITestingStore, arguments: arguments),
           try context.fetchCount(FetchDescriptor<Quest>()) == 0 {
            try seedRecoveryFixture(in: context, arguments: arguments)
        }
    }

    private static func seedStoreScreenshotFixture(in context: ModelContext) throws {
        let now = Date.now
        let fixtures: [(LocalizedStringResource, TimeInterval, Importance)] = [
            (AppStrings.debugFixtureScreenshotPrepare, 3_600, .high),
            (AppStrings.debugFixtureScreenshotPrivacyPolicy, 86_400, .medium),
            (AppStrings.debugFixtureScreenshotLandingPage, 2 * 86_400, .high),
            (AppStrings.debugFixtureScreenshotLaunchChecklist, 5 * 86_400, .low),
        ]
        for (title, interval, importance) in fixtures {
            context.insert(Quest(
                title: AppStrings.resolve(title, locale: .current),
                deadline: now.addingTimeInterval(interval),
                importance: importance
            ))
        }
        try context.save()
    }

    private static func seedHallOfFameFixture(in context: ModelContext) throws {
        let now = Date.now
        context.insert(Quest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            title: AppStrings.resolve(AppStrings.debugFixtureHallOfFameRecentVictory, locale: .current),
            deadline: now.addingTimeInterval(-600),
            importance: .medium,
            completedAt: now.addingTimeInterval(-1_200)
        ))
        context.insert(Quest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            title: AppStrings.resolve(AppStrings.debugFixtureHallOfFameLongTitle, locale: .current),
            deadline: now.addingTimeInterval(-86_400),
            importance: .high,
            completedAt: now.addingTimeInterval(-172_800)
        ))
        try context.save()
    }

    private static func seedRoutineFixture(in context: ModelContext) throws {
        let createdAt = Date.now.addingTimeInterval(-60)
        context.insert(RoutineRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            title: AppStrings.resolve(AppStrings.debugFixtureRoutineOne, locale: .current),
            createdAt: createdAt
        ))
        context.insert(RoutineRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
            title: AppStrings.resolve(AppStrings.debugFixtureRoutineTwo, locale: .current),
            createdAt: createdAt
        ))
        context.insert(RoutineRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
            title: AppStrings.resolve(AppStrings.debugFixtureRoutineThree, locale: .current),
            createdAt: createdAt
        ))
        try context.save()
    }

    private static func seedRecoveryFixture(in context: ModelContext, arguments: [String]) throws {
        let now = Date.now
        if !arguments.contains("-uiTestingRecoveryPersistenceFailure") {
            context.insert(RetentionInstallation(
                installationID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                measurementStartedAt: now.addingTimeInterval(-4 * 86_400)
            ))
        }
        if arguments.contains("-uiTestingRecoveryNoPending") {
            context.insert(Quest(
                title: AppStrings.resolve(AppStrings.debugFixtureRecoveryLeftoverQuest, locale: .current),
                deadline: now.addingTimeInterval(-60),
                importance: .medium
            ))
        } else {
            context.insert(Quest(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                title: AppStrings.resolve(AppStrings.debugFixtureRecoveryQuestOne, locale: .current),
                deadline: now.addingTimeInterval(600),
                importance: .high
            ))
            context.insert(Quest(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                title: AppStrings.resolve(AppStrings.debugFixtureRecoveryQuestTwo, locale: .current),
                deadline: now.addingTimeInterval(1_200),
                importance: .medium
            ))
        }
        context.insert(Quest(
            title: AppStrings.resolve(AppStrings.debugFixtureRecoveryVictorySecured, locale: .current),
            deadline: now.addingTimeInterval(-86_400),
            importance: .low,
            completedAt: now.addingTimeInterval(-86_460)
        ))
        // The recovery card only appears after a multi-day absence, which is derived from `lastOpened`.
        UserDefaults.standard.set(
            now.addingTimeInterval(-3 * 86_400).timeIntervalSinceReferenceDate,
            forKey: "lastOpenedTIRD"
        )
        // Cleared so the run does not inherit an acknowledgement from an earlier test. Without this
        // the weekly review can never appear here, and the assertion that it stays away after a
        // recovery action would pass against a build that had no such rule at all.
        UserDefaults.standard.set(0.0, forKey: "weeklyReviewAcknowledgedWeekTIRD")
        try context.save()
    }

    /// Victories dated into the week the review card reports, plus one in the week before it so the
    /// change figure is not zero. Dates are computed from the same calendar the card derives with,
    /// because a fixture that hard-codes a date renders nothing once that date is two weeks old.
    private static func seedWeeklyReviewFixture(in context: ModelContext) throws {
        let now = Date.now
        let calendar = Calendar.current
        guard let week = WeeklyReviewState.reviewedWeek(now: now, calendar: calendar),
              let priorWeekAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start),
              let priorWeek = calendar.dateInterval(of: .weekOfYear, for: priorWeekAnchor) else {
            return
        }

        func victory(_ title: LocalizedStringResource, at completedAt: Date) {
            context.insert(Quest(
                title: AppStrings.resolve(title, locale: .current),
                deadline: completedAt.addingTimeInterval(3_600),
                importance: .medium,
                completedAt: completedAt
            ))
        }

        // Two distinct local days inside the reviewed week, three victories, one the week before.
        victory(AppStrings.debugFixtureWeeklyReviewFirst, at: week.start.addingTimeInterval(86_400 + 32_400))
        victory(AppStrings.debugFixtureWeeklyReviewSecond, at: week.start.addingTimeInterval(86_400 + 64_800))
        victory(AppStrings.debugFixtureWeeklyReviewThird, at: week.start.addingTimeInterval(3 * 86_400 + 32_400))
        victory(AppStrings.debugFixtureWeeklyReviewPrior, at: priorWeek.start.addingTimeInterval(2 * 86_400 + 32_400))

        // The card is gated on both of these: an acknowledgement from an earlier run would hide it,
        // and a stale `lastOpened` would hand the board to the recovery card instead.
        UserDefaults.standard.set(0.0, forKey: "weeklyReviewAcknowledgedWeekTIRD")
        UserDefaults.standard.set(now.timeIntervalSinceReferenceDate, forKey: "lastOpenedTIRD")
        try context.save()
    }
}
#endif
