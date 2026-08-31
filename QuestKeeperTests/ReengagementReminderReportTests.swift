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
            event(1, .reengagementPermissionRequested, key: "permission-request-1"),
            event(2, .reengagementPermissionRequested, key: "permission-request-2"),
            event(3, .reengagementPermissionGranted, key: "permission-granted-1"),
            event(4, .reengagementReminderEnabled, key: "reminder-enabled-1"),
            event(5, .reengagementReminderEnabled, key: "reminder-enabled-2"),
            event(6, .reengagementReminderDisabled, key: "reminder-disabled-1"),
            event(7, .reengagementNotificationOpened, key: "opened-1", questID: firstQuestID),
            event(8, .reengagementNotificationOpened, key: "opened-2", questID: secondQuestID),
            event(9, .reengagementNotificationCompleted, key: "completed-1", questID: firstQuestID),
        ])

        #expect(report.permissionGrantRate == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.reminderDisableRate == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.notificationCompletionRate == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.dataQuality.status == .complete)
    }

    @Test("report excludes duplicate invalid and future reengagement events")
    func invalidEventsDoNotChangeRates() {
        let duplicateKey = "permission-request-duplicate"
        let report = makeReport(events: [
            event(1, .reengagementPermissionRequested, key: duplicateKey, offset: -2),
            event(2, .reengagementPermissionRequested, key: duplicateKey, offset: -1),
            event(3, .reengagementNotificationOpened, key: "opened-without-quest"),
            event(4, .reengagementReminderEnabled, key: "enabled-with-quest", questID: firstQuestID),
            event(5, .reengagementPermissionGranted, key: "future-grant", offset: 1, from: now),
        ], asOf: now)

        #expect(report.permissionGrantRate == RetentionRate(achieved: 0, eligible: 1))
        #expect(report.reminderDisableRate == RetentionRate(achieved: 0, eligible: 0))
        #expect(report.notificationCompletionRate == RetentionRate(achieved: 0, eligible: 0))
        #expect(report.dataQuality.duplicateCountsByEvent[RetentionEventName.reengagementPermissionRequested.rawValue] == 1)
        #expect(report.dataQuality.unsupportedCount == 2)
        #expect(report.dataQuality.futureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("report store round-trips stable privacy-safe JSON")
    func storeRoundTripsReport() throws {
        let fileURL = temporaryDirectory().appending(path: ReengagementReminderStore.fileName)
        let store = ReengagementReminderStore(fileURL: fileURL)
        let report = makeReport(events: [
            event(1, .reengagementPermissionRequested, key: "permission-request"),
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

    private func event(
        _ id: Int,
        _ name: RetentionEventName,
        key: String,
        questID: UUID? = nil,
        offset: TimeInterval = 0,
        from base: Date? = nil
    ) -> RetentionEventSnapshot {
        RetentionEventSnapshot(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            schemaVersion: RetentionEvent.currentSchemaVersion,
            nameRawValue: name.rawValue,
            installationID: installationID,
            occurredAt: (base ?? now).addingTimeInterval(offset),
            sourceRawValue: RetentionEventSource.app.rawValue,
            questID: questID,
            deduplicationKey: key
        )
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-reengagement-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
