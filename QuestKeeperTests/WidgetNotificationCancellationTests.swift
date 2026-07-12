//
//  WidgetNotificationCancellationTests.swift
//  QuestKeeperTests
//
//  Spec 009 — the widget must cancel exactly the notifications the app scheduled.
//

import Foundation
import Testing
@testable import QuestKeeper

struct WidgetNotificationCancellationTests {
    @Test("widget cancels exactly the identifiers the planner schedules")
    func cancellationIdentifiersMatchPlanner() {
        let id = UUID()
        let scheduled = Set(QuestNotificationPlanner.identifiers(for: id))
        let widgetCancels = Set(QuestNotificationKind.allCases.map { $0.identifier(for: id) })
        #expect(widgetCancels == scheduled)
    }
}
