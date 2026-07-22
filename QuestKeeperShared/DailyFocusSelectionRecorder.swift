import Foundation
import OSLog
import SwiftData

nonisolated enum DailyFocusSelectionRecordResult: Equatable, Sendable {
    case inserted(DailyFocusSelectionSnapshot)
    case unchanged(DailyFocusSelectionSnapshot)
    case failed
}

@MainActor
enum DailyFocusSelectionRecorder {
    private static let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "DailyFocus"
    )

    static func record(
        selectedQuestIDs: [UUID],
        kind: DailyFocusSelectionKind,
        at recordedAt: Date,
        calendar: Calendar,
        in context: ModelContext
    ) -> DailyFocusSelectionRecordResult {
        do {
            guard (1...3).contains(selectedQuestIDs.count),
                  Set(selectedQuestIDs).count == selectedQuestIDs.count else {
                return .failed
            }

            let installations = try context.fetch(FetchDescriptor<RetentionInstallation>())
            guard installations.count == 1,
                  let installation = installations.first,
                  installation.schemaVersion == RetentionInstallation.currentSchemaVersion else {
                return .failed
            }

            let quests = try context.fetch(FetchDescriptor<Quest>())
            let questsByID = Dictionary(uniqueKeysWithValues: quests.map { ($0.id, $0) })
            guard selectedQuestIDs.allSatisfy({
                guard let quest = questsByID[$0] else { return false }
                return quest.completedAt == nil && quest.deadline >= recordedAt
            }) else {
                return .failed
            }
            let orderedQuestIDs = selectedQuestIDs.sorted {
                guard let lhs = questsByID[$0], let rhs = questsByID[$1] else { return false }
                if lhs.deadline != rhs.deadline { return lhs.deadline < rhs.deadline }
                if lhs.importance != rhs.importance {
                    return lhs.importance.rawValue > rhs.importance.rawValue
                }
                return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
            }

            let dayKey = DailyFocusDay.key(for: recordedAt, calendar: calendar)
            let rows = try context.fetch(FetchDescriptor<DailyFocusSelection>())
                .map(\.snapshot)
                .filter {
                    $0.schemaVersion == DailyFocusSelection.currentSchemaVersion
                        && $0.installationID == installation.installationID
                        && $0.localDayKey == dayKey
                        && $0.timeZoneIdentifier == calendar.timeZone.identifier
                        && $0.kind != nil
                        && $0.selectedQuestIDs != nil
                }
                .sorted(by: snapshotOrdering)

            let confirmation = rows.first { $0.kind == .confirmation }
            if let latest = rows.last, latest.selectedQuestIDs == orderedQuestIDs {
                return .unchanged(latest)
            }
            switch kind {
            case .confirmation:
                guard confirmation == nil else { return .failed }
            case .revision:
                guard confirmation != nil else { return .failed }
            }

            let data = try JSONEncoder().encode(orderedQuestIDs.map(\.uuidString))
            let selection = DailyFocusSelection(
                installationID: installation.installationID,
                localDayKey: dayKey,
                timeZoneIdentifier: calendar.timeZone.identifier,
                selectedQuestIDsData: data,
                recordedAt: recordedAt,
                kind: kind
            )
            context.insert(selection)
            do {
                try context.save()
                return .inserted(selection.snapshot)
            } catch {
                context.delete(selection)
                throw error
            }
        } catch {
            logger.error("Failed to record daily focus selection: \(String(describing: error), privacy: .public)")
            return .failed
        }
    }

    nonisolated private static func snapshotOrdering(
        _ lhs: DailyFocusSelectionSnapshot,
        _ rhs: DailyFocusSelectionSnapshot
    ) -> Bool {
        if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt < rhs.recordedAt }
        return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
    }
}
