import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

struct RetentionBaselineStoreTests {
    @MainActor
    @Test("writer records one activation and writes its live report")
    func writerRecordsActivationAndReport() throws {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = RetentionBaselineStore(
            fileURL: temporaryDirectory().appending(path: RetentionBaselineStore.fileName)
        )
        let experimentStore = OnboardingExperimentStore(
            fileURL: temporaryDirectory().appending(path: OnboardingExperimentStore.fileName)
        )
        let writer = RetentionBaselineWriter(store: store, onboardingStore: experimentStore)
        let now = RetentionBaselineFixture.date("2026-07-08T01:00:00Z")
        let installationID = RetentionBaselineFixture.uuid(501)
        let assignedAt = now.addingTimeInterval(-1)
        container.mainContext.insert(RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: assignedAt
        ))
        container.mainContext.insert(ExperimentAssignment(
            installationID: installationID,
            variant: .guided,
            assignedAt: assignedAt
        ))
        try container.mainContext.save()

        writer.recordActivationAndWrite(
            sessionID: RetentionBaselineFixture.uuid(500),
            at: now,
            using: container,
            calendar: RetentionBaselineFixture.calendar
        )

        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionEvent>()).count == 1)
        #expect(store.load()?.weeklyActiveInstallations == 1)
        #expect(store.load()?.firstValue == RetentionRate(achieved: 0, eligible: 1))
        #expect(experimentStore.load()?.guided.funnel.exposed == 0)
        #expect(experimentStore.load()?.dataQuality.missingExposureCount == 1)
    }

    @MainActor
    @Test("experiment report failure preserves activation and core report")
    func experimentFailureDoesNotUndoCoreMeasurement() throws {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = RetentionBaselineStore(
            fileURL: temporaryDirectory().appending(path: RetentionBaselineStore.fileName)
        )
        let now = RetentionBaselineFixture.date("2026-07-08T01:00:00Z")
        let assignedAt = now.addingTimeInterval(-1)
        let installationID = RetentionBaselineFixture.uuid(502)
        container.mainContext.insert(RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: assignedAt
        ))
        container.mainContext.insert(ExperimentAssignment(
            installationID: installationID,
            variant: .control,
            assignedAt: assignedAt
        ))
        try container.mainContext.save()
        let writer = RetentionBaselineWriter(
            store: store,
            onboardingStore: OnboardingExperimentStore(fileURL: nil)
        )

        writer.recordActivationAndWrite(
            sessionID: RetentionBaselineFixture.uuid(503),
            at: now,
            using: container,
            calendar: RetentionBaselineFixture.calendar
        )

        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionEvent>()).count == 1)
        #expect(store.load()?.weeklyActiveInstallations == 1)
    }

    @MainActor
    @Test("writer reports an unsupported-only onboarding assignment")
    func unsupportedOnlyAssignmentWritesPartialReport() throws {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let experimentStore = OnboardingExperimentStore(
            fileURL: temporaryDirectory().appending(path: OnboardingExperimentStore.fileName)
        )
        let writer = RetentionBaselineWriter(
            store: RetentionBaselineStore(
                fileURL: temporaryDirectory().appending(path: RetentionBaselineStore.fileName)
            ),
            onboardingStore: experimentStore
        )
        let now = RetentionBaselineFixture.date("2026-07-08T01:00:00Z")
        let assignedAt = now.addingTimeInterval(-1)
        let installationID = RetentionBaselineFixture.uuid(504)
        container.mainContext.insert(RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: assignedAt
        ))
        container.mainContext.insert(ExperimentAssignment(
            schemaVersion: 2,
            installationID: installationID,
            variant: .control,
            assignedAt: assignedAt
        ))
        try container.mainContext.save()

        writer.recordActivationAndWrite(
            sessionID: RetentionBaselineFixture.uuid(505),
            at: now,
            using: container,
            calendar: RetentionBaselineFixture.calendar
        )

        #expect(experimentStore.load()?.dataQuality.unsupportedCount == 1)
        #expect(experimentStore.load()?.dataQuality.status == .partial)
    }

    @Test("store round-trips stable sorted ISO-8601 JSON")
    func storeRoundTripsStableJSON() throws {
        let fileURL = temporaryDirectory().appending(path: RetentionBaselineStore.fileName)
        let store = RetentionBaselineStore(fileURL: fileURL)
        let report = baselineReport()

        try store.save(report)
        let firstBytes = try Data(contentsOf: fileURL)
        try store.save(report)
        let secondBytes = try Data(contentsOf: fileURL)

        #expect(store.load() == report)
        #expect(firstBytes == secondBytes)
        #expect(String(decoding: firstBytes, as: UTF8.self).contains("2026-07-13T15:00:00Z"))
    }

    @Test("store creates a missing parent directory")
    func storeCreatesParentDirectory() throws {
        let fileURL = temporaryDirectory()
            .appending(path: "nested", directoryHint: .isDirectory)
            .appending(path: RetentionBaselineStore.fileName)
        let store = RetentionBaselineStore(fileURL: fileURL)

        try store.save(baselineReport())

        #expect(FileManager.default.fileExists(atPath: fileURL.path()))
    }

    @Test("store throws when the App Group is unavailable")
    func storeThrowsWithoutAppGroup() {
        let store = RetentionBaselineStore(fileURL: nil)
        #expect(throws: RetentionBaselineStoreError.appGroupUnavailable) {
            try store.save(baselineReport())
        }
    }

    @Test("store returns nil for missing corrupt and unsupported files")
    func invalidFilesReturnNil() throws {
        let directory = temporaryDirectory()
        let missing = RetentionBaselineStore(fileURL: directory.appending(path: "missing.json"))
        #expect(missing.load() == nil)

        let corruptURL = directory.appending(path: "corrupt.json")
        try Data("not-json".utf8).write(to: corruptURL)
        #expect(RetentionBaselineStore(fileURL: corruptURL).load() == nil)

        let unsupportedURL = directory.appending(path: "unsupported.json")
        let report = baselineReport()
        let unsupported = RetentionReport(
            schemaVersion: RetentionReport.currentSchemaVersion + 1,
            generatedAt: report.generatedAt,
            timeZoneIdentifier: report.timeZoneIdentifier,
            reportingWeek: report.reportingWeek,
            firstValue: report.firstValue,
            firstCompletion: report.firstCompletion,
            d1: report.d1,
            d7: report.d7,
            weeklyActiveInstallations: report.weeklyActiveInstallations,
            weeklyRepeatedCompletion: report.weeklyRepeatedCompletion,
            dataQuality: report.dataQuality,
            scenarioValidation: report.scenarioValidation
        )
        try JSONEncoder.retentionBaseline.encode(unsupported).write(to: unsupportedURL)
        #expect(RetentionBaselineStore(fileURL: unsupportedURL).load() == nil)
    }

    @Test("encoded baseline excludes user content and durable person identifiers")
    func encodedBaselineRespectsPrivacyContract() throws {
        let fileURL = temporaryDirectory().appending(path: RetentionBaselineStore.fileName)
        let store = RetentionBaselineStore(fileURL: fileURL)
        try store.save(baselineReport())

        let encoded = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
        let forbidden = [
            "비공개 퀘스트 제목", "questTitle", "vendorIdentifier", "advertisingIdentifier",
            "deviceName", "email", "location", "ipAddress",
        ]
        #expect(forbidden.allSatisfy { !encoded.contains($0) })
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

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-retention-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
