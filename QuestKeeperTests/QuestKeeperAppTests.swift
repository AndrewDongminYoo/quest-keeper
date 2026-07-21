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
}
