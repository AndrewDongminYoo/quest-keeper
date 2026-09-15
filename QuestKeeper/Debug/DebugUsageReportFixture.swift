#if DEBUG
import Foundation

nonisolated enum DebugUsageReportFixture {
    static func loader(arguments: [String]) -> UsageReportExportLoader {
        if arguments.contains("-uiTestingUsageReportUnavailable") {
            return UsageReportExportLoader { _, _ in nil }
        }
        guard arguments.contains("-uiTestingUsageReportFixture") else {
            return UsageReportExportLoader()
        }
        return UsageReportExportLoader { appVersion, buildNumber in
            makeExport(appVersion: appVersion, buildNumber: buildNumber)
        }
    }

    private static func makeExport(appVersion: String, buildNumber: String) -> UsageReportExport {
        let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000901")!
        let assignedAt = Date(timeIntervalSince1970: 1_788_800_000)
        let asOf = assignedAt.addingTimeInterval(8 * 86_400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let assignment = ExperimentAssignmentSnapshot(
            schemaVersion: ExperimentAssignment.currentSchemaVersion,
            experimentKey: OnboardingExperiment.key,
            installationID: installationID,
            variantRawValue: OnboardingExperimentVariant.control.rawValue,
            assignedAt: assignedAt
        )
        let installation = RetentionInstallationSnapshot(
            schemaVersion: RetentionInstallation.currentSchemaVersion,
            installationID: installationID,
            measurementStartedAt: assignedAt
        )
        let exposure = RetentionEventSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000902")!,
            schemaVersion: RetentionEvent.currentSchemaVersion,
            nameRawValue: RetentionEventName.experimentExposed.rawValue,
            installationID: installationID,
            occurredAt: assignedAt,
            sourceRawValue: RetentionEventSource.app.rawValue,
            questID: nil,
            deduplicationKey: "experiment_exposed:\(installationID.uuidString):\(OnboardingExperiment.key)"
        )
        let activation = RetentionEventSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
            schemaVersion: RetentionEvent.currentSchemaVersion,
            nameRawValue: RetentionEventName.appActivated.rawValue,
            installationID: installationID,
            occurredAt: assignedAt,
            sourceRawValue: RetentionEventSource.app.rawValue,
            questID: nil,
            deduplicationKey: "app_activated:\(installationID.uuidString):fixture"
        )
        let events = [exposure, activation]
        let experiment = OnboardingExperimentReport.make(
            assignments: [assignment],
            installations: [installation],
            events: events,
            asOf: asOf,
            calendar: calendar,
            cohort: DateInterval(start: assignedAt, end: asOf)
        )
        let retention = RetentionReport.make(
            installations: [installation],
            events: events,
            asOf: asOf,
            calendar: calendar,
            reportingWeek: calendar.dateInterval(of: .weekOfYear, for: asOf)!
        )
        return UsageReportExport(
            appVersion: appVersion,
            buildNumber: buildNumber,
            onboardingExperiment: experiment,
            retentionBaseline: retention
        )
    }
}
#endif
