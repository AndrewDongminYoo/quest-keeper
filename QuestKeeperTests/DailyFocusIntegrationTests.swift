import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct DailyFocusIntegrationTests {
    @Test("confirmed daily focus restores from a fresh on-disk container")
    func restoresPersistedSelection() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-focus-\(UUID().uuidString).store")
        let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let now = Date(timeIntervalSince1970: 1_782_230_400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        do {
            let container = try QuestModelContainer.make(storeURL: storeURL)
            container.mainContext.insert(RetentionInstallation(
                installationID: installationID,
                measurementStartedAt: now.addingTimeInterval(-60)
            ))
            container.mainContext.insert(Quest(
                id: questID,
                title: "다시 열 퀘스트",
                deadline: now.addingTimeInterval(600),
                importance: .medium
            ))
            try container.mainContext.save()

            #expect(DailyFocusSelectionRecorder.record(
                selectedQuestIDs: [questID],
                kind: .confirmation,
                at: now,
                calendar: calendar,
                in: container.mainContext
            ).snapshot?.selectedQuestIDs == [questID])
        }

        let reopened = try QuestModelContainer.make(storeURL: storeURL)
        let rows = try reopened.mainContext.fetch(FetchDescriptor<DailyFocusSelection>())

        #expect(rows.count == 1)
        #expect(rows.first?.snapshot.selectedQuestIDs == [questID])
    }
}
private extension DailyFocusSelectionRecordResult {
    var snapshot: DailyFocusSelectionSnapshot? {
        switch self {
        case .inserted(let snapshot), .unchanged(let snapshot):
            snapshot
        case .failed:
            nil
        }
    }
}
