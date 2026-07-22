import Foundation
import Testing
@testable import QuestKeeper

struct OnboardingExperimentStoreTests {
    @Test("store round-trips stable sorted ISO-8601 JSON")
    func roundTripsStableJSON() throws {
        let fileURL = temporaryDirectory().appending(path: OnboardingExperimentStore.fileName)
        let store = OnboardingExperimentStore(fileURL: fileURL)
        let report = experimentReport()

        try store.save(report)
        let firstBytes = try Data(contentsOf: fileURL)
        try store.save(report)
        let secondBytes = try Data(contentsOf: fileURL)

        #expect(store.load() == report)
        #expect(firstBytes == secondBytes)
        #expect(String(decoding: firstBytes, as: UTF8.self).contains("2026-07-12T15:00:00Z"))
    }

    @Test("store creates a missing parent directory")
    func createsParentDirectory() throws {
        let fileURL = temporaryDirectory()
            .appending(path: "nested", directoryHint: .isDirectory)
            .appending(path: OnboardingExperimentStore.fileName)
        let store = OnboardingExperimentStore(fileURL: fileURL)

        try store.save(experimentReport())

        #expect(FileManager.default.fileExists(atPath: fileURL.path()))
    }

    @Test("store throws when the App Group is unavailable")
    func throwsWithoutAppGroup() {
        let store = OnboardingExperimentStore(fileURL: nil)

        #expect(throws: RetentionBaselineStoreError.appGroupUnavailable) {
            try store.save(experimentReport())
        }
    }

    @Test("store returns nil for missing corrupt and unsupported files")
    func invalidFilesReturnNil() throws {
        let directory = temporaryDirectory()
        let missing = OnboardingExperimentStore(fileURL: directory.appending(path: "missing.json"))
        #expect(missing.load() == nil)

        let corruptURL = directory.appending(path: "corrupt.json")
        try Data("not-json".utf8).write(to: corruptURL)
        #expect(OnboardingExperimentStore(fileURL: corruptURL).load() == nil)

        let unsupportedURL = directory.appending(path: "unsupported.json")
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
        #expect(OnboardingExperimentStore(fileURL: unsupportedURL).load() == nil)
    }

    @Test("encoded report excludes user content and durable person identifiers")
    func encodedReportRespectsPrivacyContract() throws {
        let fileURL = temporaryDirectory().appending(path: OnboardingExperimentStore.fileName)
        let store = OnboardingExperimentStore(fileURL: fileURL)
        try store.save(experimentReport())

        let encoded = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
        let forbidden = [
            "비공개 퀘스트 제목", "questTitle", "vendorIdentifier", "advertisingIdentifier",
            "deviceName", "email", "location", "ipAddress",
        ]
        #expect(forbidden.allSatisfy { !encoded.contains($0) })
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

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-onboarding-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
