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
