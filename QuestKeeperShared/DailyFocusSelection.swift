import Foundation
import SwiftData

nonisolated enum DailyFocusSelectionKind: String, Codable, CaseIterable, Sendable {
    case confirmation
    case revision
}
@Model
final class DailyFocusSelection {
    static let currentSchemaVersion = 1

    private(set) var id: UUID
    private(set) var schemaVersion: Int
    private(set) var installationID: UUID
    private(set) var localDayKey: String
    private(set) var timeZoneIdentifier: String
    private(set) var selectedQuestIDsData: Data
    private(set) var recordedAt: Date
    private(set) var kindRawValue: String

    init(
        id: UUID = UUID(),
        schemaVersion: Int = currentSchemaVersion,
        installationID: UUID,
        localDayKey: String,
        timeZoneIdentifier: String,
        selectedQuestIDsData: Data,
        recordedAt: Date,
        kind: DailyFocusSelectionKind
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.installationID = installationID
        self.localDayKey = localDayKey
        self.timeZoneIdentifier = timeZoneIdentifier
        self.selectedQuestIDsData = selectedQuestIDsData
        self.recordedAt = recordedAt
        self.kindRawValue = kind.rawValue
    }

    var snapshot: DailyFocusSelectionSnapshot {
        DailyFocusSelectionSnapshot(
            id: id,
            schemaVersion: schemaVersion,
            installationID: installationID,
            localDayKey: localDayKey,
            timeZoneIdentifier: timeZoneIdentifier,
            selectedQuestIDsData: selectedQuestIDsData,
            recordedAt: recordedAt,
            kindRawValue: kindRawValue
        )
    }
}

nonisolated struct DailyFocusSelectionSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let schemaVersion: Int
    let installationID: UUID
    let localDayKey: String
    let timeZoneIdentifier: String
    let selectedQuestIDsData: Data
    let recordedAt: Date
    let kindRawValue: String

    var kind: DailyFocusSelectionKind? {
        DailyFocusSelectionKind(rawValue: kindRawValue)
    }

    var selectedQuestIDs: [UUID]? {
        guard let values = try? JSONDecoder().decode([String].self, from: selectedQuestIDsData) else {
            return nil
        }
        let ids = values.compactMap(UUID.init(uuidString:))
        return ids.count == values.count ? ids : nil
    }
}

nonisolated enum DailyFocusDay {
    static func key(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
