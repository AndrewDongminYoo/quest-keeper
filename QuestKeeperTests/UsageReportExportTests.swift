import Foundation
import Testing
@testable import QuestKeeper

struct UsageReportExportTests {
    @Test("loader exports aggregate experiment and retention reports with app version metadata")
    func exportsAvailableAggregateReports() throws {
        let directory = temporaryDirectory()
        let onboardingStore = OnboardingExperimentStore(
            fileURL: directory.appending(path: OnboardingExperimentStore.fileName)
        )
        let retentionStore = RetentionBaselineStore(
            fileURL: directory.appending(path: RetentionBaselineStore.fileName)
        )
        let onboardingReport = experimentReport()
        let retentionReport = baselineReport()
        try onboardingStore.save(onboardingReport)
        try retentionStore.save(retentionReport)

        let export = UsageReportExportLoader(
            onboardingStore: onboardingStore,
            retentionStore: retentionStore
        ).load(appVersion: "1.4.0", buildNumber: "26090413")

        #expect(export?.schemaVersion == UsageReportExport.currentSchemaVersion)
        #expect(export?.appVersion == "1.4.0")
        #expect(export?.buildNumber == "26090413")
        #expect(export?.onboardingExperiment.experimentKey == onboardingReport.experimentKey)
        #expect(export?.onboardingExperiment.control.funnel.exposed == onboardingReport.control.funnel.exposed)
        #expect(export?.retentionBaseline?.firstValue.achieved == retentionReport.firstValue.achieved)
        #expect(export?.retentionBaseline?.weeklyActiveInstallations == retentionReport.weeklyActiveInstallations)
    }

    @Test("loader keeps a valid experiment export when retention is unavailable")
    func exportsWithoutOptionalRetention() throws {
        let directory = temporaryDirectory()
        let onboardingStore = OnboardingExperimentStore(
            fileURL: directory.appending(path: OnboardingExperimentStore.fileName)
        )
        try onboardingStore.save(experimentReport())

        let export = UsageReportExportLoader(
            onboardingStore: onboardingStore,
            retentionStore: RetentionBaselineStore(
                fileURL: directory.appending(path: "missing-retention.json")
            )
        ).load(appVersion: "1.4.0", buildNumber: "26090413")

        #expect(export != nil)
        #expect(export?.retentionBaseline == nil)
    }

    @Test("loader rejects missing corrupt and unsupported experiment reports")
    func rejectsInvalidRequiredExperiment() throws {
        let directory = temporaryDirectory()
        let retentionStore = RetentionBaselineStore(
            fileURL: directory.appending(path: RetentionBaselineStore.fileName)
        )
        try retentionStore.save(baselineReport())

        let missing = UsageReportExportLoader(
            onboardingStore: OnboardingExperimentStore(
                fileURL: directory.appending(path: "missing-experiment.json")
            ),
            retentionStore: retentionStore
        )
        #expect(missing.load(appVersion: "1.4.0", buildNumber: "26090413") == nil)

        let corruptURL = directory.appending(path: "corrupt-experiment.json")
        try Data("not-json".utf8).write(to: corruptURL)
        let corrupt = UsageReportExportLoader(
            onboardingStore: OnboardingExperimentStore(fileURL: corruptURL),
            retentionStore: retentionStore
        )
        #expect(corrupt.load(appVersion: "1.4.0", buildNumber: "26090413") == nil)

        let unsupportedURL = directory.appending(path: "unsupported-experiment.json")
        let report = experimentReport()
        let unsupported = OnboardingExperimentReport(
            schemaVersion: OnboardingExperimentReport.currentSchemaVersion + 1,
            experimentKey: report.experimentKey,
            generatedAt: report.generatedAt,
            timeZoneIdentifier: report.timeZoneIdentifier,
            cohort: report.cohort,
            control: report.control,
            guided: report.guided,
            guidedDeferral: report.guidedDeferral,
            dataQuality: report.dataQuality
        )
        try JSONEncoder.retentionBaseline.encode(unsupported).write(to: unsupportedURL)
        let unsupportedLoader = UsageReportExportLoader(
            onboardingStore: OnboardingExperimentStore(fileURL: unsupportedURL),
            retentionStore: retentionStore
        )
        #expect(unsupportedLoader.load(appVersion: "1.4.0", buildNumber: "26090413") == nil)
    }

    @Test("encoded export excludes identifiers raw events and task content")
    func encodedExportRespectsPrivacyContract() throws {
        let sourceRetention = baselineReport()
        let secretUUID = "00000000-0000-0000-0000-000000000999"
        let retentionWithRawScenarioKeys = RetentionReport(
            schemaVersion: sourceRetention.schemaVersion,
            generatedAt: sourceRetention.generatedAt,
            timeZoneIdentifier: sourceRetention.timeZoneIdentifier,
            reportingWeek: sourceRetention.reportingWeek,
            firstValue: sourceRetention.firstValue,
            firstCompletion: sourceRetention.firstCompletion,
            d1: sourceRetention.d1,
            d7: sourceRetention.d7,
            weeklyActiveInstallations: sourceRetention.weeklyActiveInstallations,
            weeklyRepeatedCompletion: sourceRetention.weeklyRepeatedCompletion,
            dataQuality: sourceRetention.dataQuality,
            scenarioValidation: RetentionScenarioValidation(
                missingKeys: ["quest_completed:\(secretUUID)"],
                forbiddenKeys: ["notification_sent:\(secretUUID)"]
            )
        )
        let export = UsageReportExport(
            appVersion: "1.4.0",
            buildNumber: "26090413",
            onboardingExperiment: experimentReport(),
            retentionBaseline: retentionWithRawScenarioKeys
        )

        let data = try export.encodedJSON()
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = recursiveKeys(in: object)
        let onboarding = try #require(object["onboardingExperiment"] as? [String: Any])
        let retention = try #require(object["retentionBaseline"] as? [String: Any])
        let forbiddenKeys: Set<String> = [
            "installationID",
            "questID",
            "questTitle",
            "questDescription",
            "notificationContent",
            "events",
            "email",
            "advertisingIdentifier",
            "vendorIdentifier",
            "deviceName",
            "ipAddress",
        ]

        #expect(keys.isDisjoint(with: forbiddenKeys))
        #expect(Set(object.keys) == [
            "schemaVersion", "appVersion", "buildNumber", "onboardingExperiment", "retentionBaseline",
        ])
        #expect(Set(onboarding.keys) == [
            "schemaVersion", "experimentKey", "generatedAt", "timeZoneIdentifier", "cohort", "control",
            "guided", "guidedDeferral", "dataQuality",
        ])
        #expect(Set(retention.keys) == [
            "schemaVersion", "generatedAt", "timeZoneIdentifier", "reportingWeek", "firstValue",
            "firstCompletion", "d1", "d7", "weeklyActiveInstallations", "weeklyRepeatedCompletion",
            "dataQuality",
        ])
        #expect(!String(decoding: data, as: UTF8.self).contains(secretUUID))
        #expect(String(decoding: data, as: UTF8.self).contains("2026-07-12T15:00:00Z"))
    }

    private func experimentReport() -> OnboardingExperimentReport {
        OnboardingExperimentReport.make(
            assignments: OnboardingExperimentFixture.assignments,
            installations: OnboardingExperimentFixture.installations,
            events: OnboardingExperimentFixture.events,
            asOf: OnboardingExperimentFixture.asOf,
            calendar: OnboardingExperimentFixture.calendar,
            cohort: OnboardingExperimentFixture.cohort
        )
    }

    private func baselineReport() -> RetentionReport {
        RetentionReport.make(
            installations: RetentionBaselineFixture.installations,
            events: RetentionBaselineFixture.events,
            asOf: RetentionBaselineFixture.asOf,
            calendar: RetentionBaselineFixture.calendar,
            reportingWeek: RetentionBaselineFixture.reportingWeek,
            expectation: RetentionBaselineFixture.expectation
        )
    }

    private func recursiveKeys(in value: Any) -> Set<String> {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: Set(dictionary.keys)) { result, entry in
                result.formUnion(recursiveKeys(in: entry.value))
            }
        }
        if let array = value as? [Any] {
            return array.reduce(into: []) { result, item in
                result.formUnion(recursiveKeys(in: item))
            }
        }
        return []
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-usage-report-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
