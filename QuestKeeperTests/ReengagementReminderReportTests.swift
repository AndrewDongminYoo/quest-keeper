import Foundation
import Testing
@testable import QuestKeeper

struct ReengagementReminderReportTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let firstQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    private let secondQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("canonical reengagement events compute the three local rates")
    func canonicalEventsComputeRates() {
        let report = makeReport(events: [
            event(1, .reengagementPermissionRequested, action: "action-1", offset: -9),
            event(2, .reengagementPermissionRequested, action: "action-2", offset: -8),
            event(3, .reengagementPermissionGranted, action: "action-1", offset: -7),
            event(4, .reengagementReminderEnabled, action: "action-3", offset: -6),
            event(5, .reengagementReminderEnabled, action: "action-4", offset: -5),
            event(6, .reengagementReminderDisabled, action: "action-5", offset: -4),
            event(7, .reengagementNotificationOpened, action: "action-6", questID: firstQuestID, offset: -3),
            event(8, .reengagementNotificationOpened, action: "action-7", questID: secondQuestID, offset: -2),
            event(9, .reengagementNotificationCompleted, action: "action-6", questID: firstQuestID, offset: -1),
        ])

        #expect(report.permissionGrantRate == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.reminderDisableRate == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.notificationCompletionRate == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.dataQuality.orphanCountsByEvent.isEmpty)
        #expect(report.dataQuality.status == .complete)
    }

    @Test("report excludes duplicate invalid and future reengagement events")
    func invalidEventsDoNotChangeRates() {
        let report = makeReport(events: [
            event(1, .reengagementPermissionRequested, action: "duplicated", offset: -2),
            event(2, .reengagementPermissionRequested, action: "duplicated", offset: -1),
            event(3, .reengagementNotificationOpened, action: "opened-without-quest"),
            event(4, .reengagementReminderEnabled, action: "enabled-with-quest", questID: firstQuestID),
            event(5, .reengagementPermissionGranted, action: "duplicated", offset: 1, from: now),
        ], asOf: now)

        #expect(report.permissionGrantRate == RetentionRate(achieved: 0, eligible: 1))
        #expect(report.reminderDisableRate == RetentionRate(achieved: 0, eligible: 0))
        #expect(report.notificationCompletionRate == RetentionRate(achieved: 0, eligible: 0))
        #expect(report.dataQuality.duplicateCountsByEvent[RetentionEventName.reengagementPermissionRequested.rawValue] == 1)
        #expect(report.dataQuality.unsupportedCount == 2)
        #expect(report.dataQuality.futureCount == 1)
        #expect(report.dataQuality.orphanCountsByEvent.isEmpty)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("report store round-trips stable privacy-safe JSON")
    func storeRoundTripsReport() throws {
        let fileURL = temporaryDirectory().appending(path: ReengagementReminderStore.fileName)
        let store = ReengagementReminderStore(fileURL: fileURL)
        let report = makeReport(events: [
            event(1, .reengagementPermissionRequested, action: "permission-request"),
        ])

        try store.save(report)
        let firstBytes = try Data(contentsOf: fileURL)
        try store.save(report)
        let secondBytes = try Data(contentsOf: fileURL)

        #expect(store.load() == report)
        #expect(firstBytes == secondBytes)
        let encoded = String(decoding: firstBytes, as: UTF8.self)
        #expect(!encoded.contains("비공개 퀘스트 제목"))
        #expect(!encoded.contains(firstQuestID.uuidString))
    }

    @Test("a grant whose request was never recorded is excluded and counted as an orphan")
    func orphanGrantIsExcludedAndCounted() {
        let report = makeReport(events: [
            event(1, .reengagementPermissionRequested, action: "action-1", offset: -9),
            event(2, .reengagementPermissionGranted, action: "action-1", offset: -2),
            // Its request was lost: `saveReengagementSettings` records the request and commits, and
            // only the grant survives on its own commit when that first one fails.
            event(3, .reengagementPermissionGranted, action: "action-orphan", offset: -1),
        ])

        #expect(report.permissionGrantRate == RetentionRate(achieved: 1, eligible: 1))
        #expect(
            report.dataQuality
                .orphanCountsByEvent[RetentionEventName.reengagementPermissionGranted.rawValue] == 1
        )
        #expect(report.dataQuality.status == .partial)
    }

    @Test("a disable is matched by an earlier enable, not by a shared action ID")
    func disableMatchesAnEarlierEnable() {
        // Enabling and disabling are separate user actions and `saveReengagementSettings` mints a
        // fresh `actionID` for each, so matching them by action ID would orphan every disable and
        // pin the rate at zero.
        let matched = makeReport(events: [
            event(1, .reengagementReminderEnabled, action: "action-enable", offset: -2),
            event(2, .reengagementReminderDisabled, action: "action-disable", offset: -1),
        ])
        let orphaned = makeReport(events: [
            event(3, .reengagementReminderDisabled, action: "action-disable", offset: -1),
        ])

        #expect(matched.reminderDisableRate == RetentionRate(achieved: 1, eligible: 1))
        #expect(matched.dataQuality.orphanCountsByEvent.isEmpty)
        #expect(orphaned.reminderDisableRate == RetentionRate(achieved: 0, eligible: 0))
        #expect(
            orphaned.dataQuality
                .orphanCountsByEvent[RetentionEventName.reengagementReminderDisabled.rawValue] == 1
        )
        #expect(orphaned.dataQuality.status == .partial)
    }

    @Test("each enable is consumed by one disable, so a lost enable still shows as an orphan")
    func oneEnableSatisfiesOnlyOneDisable() {
        let report = makeReport(events: [
            event(1, .reengagementReminderEnabled, action: "action-enable-1", offset: -4),
            event(2, .reengagementReminderDisabled, action: "action-disable-1", offset: -3),
            // The second cycle's enable was never recorded. Reusing the first one would report this
            // disable as matched and leave the status `.complete`, hiding the loss.
            event(3, .reengagementReminderDisabled, action: "action-disable-2", offset: -1),
        ])

        #expect(report.reminderDisableRate == RetentionRate(achieved: 1, eligible: 1))
        #expect(
            report.dataQuality
                .orphanCountsByEvent[RetentionEventName.reengagementReminderDisabled.rawValue] == 1
        )
        #expect(report.dataQuality.status == .partial)
    }

    @Test("a request satisfies one permission outcome, so a second is an orphan")
    func oneRequestSatisfiesOnlyOnePermissionOutcome() {
        // `saveReengagementSettings` switches on the resolved authorization and records exactly one
        // outcome per request, so this shape should not exist. Counting it as two matched outcomes
        // with a `.complete` status would hide precisely the kind of malformation this report is for.
        let report = makeReport(events: [
            event(1, .reengagementPermissionRequested, action: "action-1", offset: -3),
            event(2, .reengagementPermissionGranted, action: "action-1", offset: -2),
            event(3, .reengagementPermissionDenied, action: "action-1", offset: -1),
        ])

        #expect(report.permissionGrantRate == RetentionRate(achieved: 1, eligible: 1))
        #expect(
            report.dataQuality
                .orphanCountsByEvent[RetentionEventName.reengagementPermissionDenied.rawValue] == 1
        )
        #expect(report.dataQuality.status == .partial)
    }

    @Test("a completion is matched only by an opening of the same quest")
    func completionMatchesTheOpeningOfItsOwnQuest() {
        let report = makeReport(events: [
            event(1, .reengagementNotificationOpened, action: "action-1", questID: firstQuestID, offset: -2),
            // Same action ID, different quest. The pair is per-quest, so this is no evidence that
            // the reminder for `secondQuestID` was ever opened.
            event(2, .reengagementNotificationCompleted, action: "action-1", questID: secondQuestID, offset: -1),
        ])

        #expect(report.notificationCompletionRate == RetentionRate(achieved: 0, eligible: 1))
        #expect(
            report.dataQuality
                .orphanCountsByEvent[RetentionEventName.reengagementNotificationCompleted.rawValue] == 1
        )
        #expect(report.dataQuality.status == .partial)
    }

    private func makeReport(
        events: [RetentionEventSnapshot],
        asOf: Date? = nil
    ) -> ReengagementReminderReport {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return ReengagementReminderReport.make(
            events: events,
            asOf: asOf ?? now,
            calendar: calendar
        )
    }

    /// Builds the key through the recorder's own formatter rather than by hand. Pair matching reads
    /// the trailing component back out, so a fixture that spelled the format itself could drift
    /// from the shape the recorder writes and still pass.
    private func event(
        _ id: Int,
        _ name: RetentionEventName,
        action: String,
        questID: UUID? = nil,
        offset: TimeInterval = 0,
        from base: Date? = nil
    ) -> RetentionEventSnapshot {
        let keyComponent = questID.map { "\($0.uuidString):\(action)" } ?? action
        return RetentionEventSnapshot(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            schemaVersion: RetentionEvent.currentSchemaVersion,
            nameRawValue: name.rawValue,
            installationID: installationID,
            occurredAt: (base ?? now).addingTimeInterval(offset),
            sourceRawValue: RetentionEventSource.app.rawValue,
            questID: questID,
            deduplicationKey: RetentionEventRecorder.deduplicationKey(
                name: name,
                installationID: installationID,
                keyComponent: keyComponent
            )
        )
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-reengagement-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
