//
//  QuestKeeperAppTests.swift
//  QuestKeeperTests
//
//  App wiring regression tests.
//

import Foundation
import Testing
@testable import QuestKeeper

@MainActor
struct QuestKeeperAppTests {
    @Test("QuestKeeperApp owns a widget snapshot writer")
    func appOwnsStableWidgetWriter() {
        let app = QuestKeeperApp()

        let labels = Mirror(reflecting: app).children.compactMap(\.label)
        #expect(labels.contains { $0.contains("widgetSnapshotWriter") })
        #expect(labels.contains { $0.contains("onboardingSessionID") })
        #expect(labels.contains { $0.contains("hasDeferredOnboardingThisRun") })
    }

    @Test(
        "onboarding variant override accepts only supported variants",
        arguments: [
            (["QuestKeeper", "-onboardingVariant", "control"], OnboardingExperimentVariant.control),
            (["QuestKeeper", "-onboardingVariant", "guided"], OnboardingExperimentVariant.guided),
            (["QuestKeeper", "-onboardingVariant", "unknown"], nil),
            (["QuestKeeper"], nil),
        ]
    )
    func onboardingOverride(
        arguments: [String],
        expected: OnboardingExperimentVariant?
    ) {
        #expect(onboardingVariantOverride(arguments: arguments) == expected)
    }

    @Test(
        "daily focus loop requires its exact development argument",
        arguments: [
            (["QuestKeeper", "-dailyFocusLoopEnabled"], true),
            (["QuestKeeper", "dailyFocusLoopEnabled"], false),
            (["QuestKeeper"], false),
        ]
    )
    func dailyFocusGate(arguments: [String], expected: Bool) {
        #expect(dailyFocusLoopEnabled(arguments: arguments) == expected)
    }

    @Test(
        "recovery variant requires daily focus and an exact supported value",
        arguments: [
            (
                ["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant", "singleQuest"],
                true,
                RecoveryLoopVariant.singleQuest
            ),
            (
                ["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant", "chooseToday"],
                true,
                RecoveryLoopVariant.chooseToday
            ),
            (["QuestKeeper", "-recoveryLoopVariant", "singleQuest"], false, nil),
            (
                ["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant", "unknown"],
                true,
                nil
            ),
            (["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant"], true, nil),
        ]
    )
    func recoveryVariantGate(
        arguments: [String],
        dailyFocusEnabled: Bool,
        expected: RecoveryLoopVariant?
    ) {
        #expect(recoveryLoopVariant(
            arguments: arguments,
            dailyFocusLoopEnabled: dailyFocusEnabled
        ) == expected)
    }

    @Test("recovery fixtures require an isolated UI test store")
    func recoveryFixtureIsolation() {
        let arguments = ["QuestKeeper", "-uiTestingRecoveryFixture"]
        #expect(shouldSeedRecoveryFixture(
            usesUITestingStore: true,
            arguments: arguments
        ))
        #expect(!shouldSeedRecoveryFixture(
            usesUITestingStore: false,
            arguments: arguments
        ))
    }

    @Test(
        "activation replay runs only for launch and genuine background return",
        arguments: [
            (false, false, true),
            (true, false, false),
            (true, true, true),
        ]
    )
    func activationReplayGate(
        hasPerformedActivationReplay: Bool,
        didBackground: Bool,
        expected: Bool
    ) {
        #expect(shouldReplayActivation(
            hasPerformedActivationReplay: hasPerformedActivationReplay,
            didBackground: didBackground
        ) == expected)
    }

    @Test("activation replay derives recovery from refreshed completion facts")
    func recoveryUsesRefreshedFacts() {
        let now = Date(timeIntervalSinceReferenceDate: 806_000_000)
        let previous = now.addingTimeInterval(-86_400)
        let calendar = DailyFocusDay.gregorianCalendar(
            timeZone: TimeZone(identifier: "Asia/Seoul")!
        )
        let firstID = UUID()
        let secondID = UUID()
        let staleQuests = [
            QuestSnapshot(
                id: firstID,
                deadline: now.addingTimeInterval(-3_600),
                completedAt: nil,
                importance: .medium
            ),
            QuestSnapshot(
                id: secondID,
                deadline: now.addingTimeInterval(-1_800),
                completedAt: nil,
                importance: .medium
            ),
        ]
        let refreshedQuests = staleQuests.map {
            QuestSnapshot(
                id: $0.id,
                deadline: $0.deadline,
                completedAt: $0.deadline.addingTimeInterval(-60),
                importance: $0.importance
            )
        }

        let stale = makeActivationReplay(
            quests: staleQuests,
            dailyFocusSelections: [],
            previousLastOpened: previous,
            now: now,
            calendar: calendar,
            dailyFocusLoopEnabled: true,
            recoveryLoopVariant: .singleQuest
        )
        let refreshed = makeActivationReplay(
            quests: refreshedQuests,
            dailyFocusSelections: [],
            previousLastOpened: previous,
            now: now,
            calendar: calendar,
            dailyFocusLoopEnabled: true,
            recoveryLoopVariant: .singleQuest
        )

        #expect(stale.result.deaths.count == 2)
        #expect(stale.result.recoveryOffer != nil)
        #expect(refreshed.result.deaths.isEmpty)
        #expect(refreshed.result.recoveryOffer == nil)
    }

#if DEBUG
    @Test("UI test store URL requires an explicit path argument")
    func uiTestStoreURL() {
        #expect(parsedUITestingStoreURL(arguments: [
            "QuestKeeper", "-uiTestingStoreURL", "/tmp/quest-keeper-ui-test/store.sqlite",
        ])?.path == "/tmp/quest-keeper-ui-test/store.sqlite")
        #expect(parsedUITestingStoreURL(arguments: ["QuestKeeper", "-uiTestingStoreURL"]) == nil)
        #expect(parsedUITestingStoreURL(arguments: ["QuestKeeper"]) == nil)
    }
#endif

    @Test("UI test stores stay isolated across background refresh")
    func uiTestStoreBackgroundReuse() {
        #expect(shouldReuseContainerOnBackground(
            usesInMemoryStore: true,
            uiTestingStoreURL: nil
        ))
        #expect(shouldReuseContainerOnBackground(
            usesInMemoryStore: false,
            uiTestingStoreURL: URL(fileURLWithPath: "/tmp/quest-keeper-ui-test/store.sqlite")
        ))
        #expect(!shouldReuseContainerOnBackground(
            usesInMemoryStore: false,
            uiTestingStoreURL: nil
        ))
    }

    @Test("daily grave fixture requires an isolated UI test store")
    func dailyGraveFixtureIsolation() {
        let arguments = ["QuestKeeper", "-uiTestingDailyFocusGrave"]
        #expect(shouldSeedDailyFocusGraveFixture(
            usesUITestingStore: true,
            arguments: arguments
        ))
        #expect(!shouldSeedDailyFocusGraveFixture(
            usesUITestingStore: false,
            arguments: arguments
        ))
    }

    @Test("previews do not resolve or expose onboarding experiments")
    func previewExclusion() {
        #expect(!shouldResolveOnboardingExperiment(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        ))
        #expect(shouldResolveOnboardingExperiment(environment: [:]))
    }

    @Test(
        "retention activation records only initial launch and background return",
        arguments: [
            (false, false, true),
            (true, false, false),
            (true, true, true),
        ]
    )
    func retentionActivationGate(
        hasRecordedActivation: Bool,
        didBackground: Bool,
        expected: Bool
    ) {
        #expect(shouldRecordRetentionActivation(
            hasRecordedActivation: hasRecordedActivation,
            didBackground: didBackground
        ) == expected)
    }

    @Test(
        "in-memory launches do not persist measurement artifacts",
        arguments: [
            (false, true),
            (true, false),
        ]
    )
    func measurementArtifactPersistenceGate(
        usesInMemoryStore: Bool,
        expected: Bool
    ) {
        #expect(shouldPersistMeasurementArtifacts(
            usesInMemoryStore: usesInMemoryStore
        ) == expected)
    }

    @Test(
        "onboarding exposure waits for the first active scene",
        arguments: [
            (true, false, true, true),
            (true, false, false, false),
            (true, true, true, false),
            (false, false, true, false),
        ]
    )
    func onboardingExposureGate(
        hasAssignment: Bool,
        hasAttempted: Bool,
        isActive: Bool,
        expected: Bool
    ) {
        #expect(shouldAttemptOnboardingExposure(
            hasAssignment: hasAssignment,
            hasAttempted: hasAttempted,
            isActive: isActive
        ) == expected)
    }

    @Test("failed exposure save rolls back pending measurement")
    func exposureSaveRollback() {
        var didRollback = false

        let available = persistOnboardingExposure(
            record: { .inserted },
            save: { throw ExposureSaveError.failed },
            rollback: { didRollback = true }
        )

        #expect(!available)
        #expect(didRollback)
    }

    private enum ExposureSaveError: Error {
        case failed
    }
}
