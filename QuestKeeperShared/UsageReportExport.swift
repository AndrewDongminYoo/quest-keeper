import Foundation

nonisolated struct UsageReportPeriod: Codable, Equatable, Sendable {
    let start: Date
    let end: Date

    init(_ interval: DateInterval) {
        start = interval.start
        end = interval.end
    }
}

nonisolated struct UsageReportRate: Codable, Equatable, Sendable {
    let achieved: Int
    let eligible: Int

    init(_ rate: RetentionRate) {
        achieved = rate.achieved
        eligible = rate.eligible
    }
}

nonisolated struct UsageReportFunnel: Codable, Equatable, Sendable {
    let exposed: Int
    let creationStarted: Int
    let firstValue: Int
    let firstCompletion: Int

    init(_ funnel: OnboardingExperimentFunnel) {
        exposed = funnel.exposed
        creationStarted = funnel.creationStarted
        firstValue = funnel.firstValue
        firstCompletion = funnel.firstCompletion
    }
}

nonisolated struct UsageReportVariantMetrics: Codable, Equatable, Sendable {
    let funnel: UsageReportFunnel
    let onboardingCompletionWithinTwoMinutes: UsageReportRate
    let firstSuccessWithinTwoMinutes: UsageReportRate
    let firstQuestCompletion: UsageReportRate
    let medianTimeToFirstValueSeconds: Double?
    let d1: UsageReportRate
    let d7: UsageReportRate

    init(_ metrics: OnboardingVariantMetrics) {
        funnel = UsageReportFunnel(metrics.funnel)
        onboardingCompletionWithinTwoMinutes = UsageReportRate(metrics.onboardingCompletionWithinTwoMinutes)
        firstSuccessWithinTwoMinutes = UsageReportRate(metrics.firstSuccessWithinTwoMinutes)
        firstQuestCompletion = UsageReportRate(metrics.firstQuestCompletion)
        medianTimeToFirstValueSeconds = metrics.medianTimeToFirstValueSeconds
        d1 = UsageReportRate(metrics.d1)
        d7 = UsageReportRate(metrics.d7)
    }
}

nonisolated struct UsageReportOnboardingDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let duplicateAssignmentCount: Int
    let conflictingAssignmentCount: Int
    let missingExposureCount: Int
    let unsupportedCount: Int
    let orderingFailureCount: Int
    let crossInstallationMismatchCount: Int
    let duplicateCountsByEvent: [String: Int]

    init(_ quality: OnboardingExperimentDataQuality) {
        status = quality.status
        duplicateAssignmentCount = quality.duplicateAssignmentCount
        conflictingAssignmentCount = quality.conflictingAssignmentCount
        missingExposureCount = quality.missingExposureCount
        unsupportedCount = quality.unsupportedCount
        orderingFailureCount = quality.orderingFailureCount
        crossInstallationMismatchCount = quality.crossInstallationMismatchCount
        duplicateCountsByEvent = quality.duplicateCountsByEvent
    }
}

nonisolated struct UsageReportOnboardingExperiment: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let experimentKey: String
    let generatedAt: Date
    let timeZoneIdentifier: String
    let cohort: UsageReportPeriod
    let control: UsageReportVariantMetrics
    let guided: UsageReportVariantMetrics
    let guidedDeferral: UsageReportRate
    let dataQuality: UsageReportOnboardingDataQuality

    init(_ report: OnboardingExperimentReport) {
        schemaVersion = report.schemaVersion
        experimentKey = report.experimentKey
        generatedAt = report.generatedAt
        timeZoneIdentifier = report.timeZoneIdentifier
        cohort = UsageReportPeriod(report.cohort)
        control = UsageReportVariantMetrics(report.control)
        guided = UsageReportVariantMetrics(report.guided)
        guidedDeferral = UsageReportRate(report.guidedDeferral)
        dataQuality = UsageReportOnboardingDataQuality(report.dataQuality)
    }
}

nonisolated struct UsageReportRetentionDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let duplicateCountsByEvent: [String: Int]
    let missingCount: Int
    let forbiddenCount: Int
    let unsupportedCount: Int
    let orphanCompletionCount: Int
    let preActivationCreationCount: Int
    let preMeasurementCount: Int
    let futureCount: Int

    init(_ quality: RetentionDataQuality) {
        status = quality.status
        duplicateCountsByEvent = quality.duplicateCountsByEvent
        missingCount = quality.missingCount
        forbiddenCount = quality.forbiddenCount
        unsupportedCount = quality.unsupportedCount
        orphanCompletionCount = quality.orphanCompletionCount
        preActivationCreationCount = quality.preActivationCreationCount
        preMeasurementCount = quality.preMeasurementCount
        futureCount = quality.futureCount
    }
}

nonisolated struct UsageReportRetention: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let timeZoneIdentifier: String
    let reportingWeek: UsageReportPeriod
    let firstValue: UsageReportRate
    let firstCompletion: UsageReportRate
    let d1: UsageReportRate
    let d7: UsageReportRate
    let weeklyActiveInstallations: Int
    let weeklyRepeatedCompletion: UsageReportRate
    let dataQuality: UsageReportRetentionDataQuality

    init(_ report: RetentionReport) {
        schemaVersion = report.schemaVersion
        generatedAt = report.generatedAt
        timeZoneIdentifier = report.timeZoneIdentifier
        reportingWeek = UsageReportPeriod(report.reportingWeek)
        firstValue = UsageReportRate(report.firstValue)
        firstCompletion = UsageReportRate(report.firstCompletion)
        d1 = UsageReportRate(report.d1)
        d7 = UsageReportRate(report.d7)
        weeklyActiveInstallations = report.weeklyActiveInstallations
        weeklyRepeatedCompletion = UsageReportRate(report.weeklyRepeatedCompletion)
        dataQuality = UsageReportRetentionDataQuality(report.dataQuality)
    }
}

nonisolated struct UsageReportExport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let appVersion: String
    let buildNumber: String
    let onboardingExperiment: UsageReportOnboardingExperiment
    let retentionBaseline: UsageReportRetention?

    init(
        appVersion: String,
        buildNumber: String,
        onboardingExperiment: OnboardingExperimentReport,
        retentionBaseline: RetentionReport?
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.onboardingExperiment = UsageReportOnboardingExperiment(onboardingExperiment)
        self.retentionBaseline = retentionBaseline.map(UsageReportRetention.init)
    }

    func encodedJSON() throws -> Data {
        try JSONEncoder.retentionBaseline.encode(self)
    }
}

nonisolated struct UsageReportExportLoader: Sendable {
    private let loadExport: @Sendable (String, String) -> UsageReportExport?

    init(
        onboardingStore: OnboardingExperimentStore = OnboardingExperimentStore(),
        retentionStore: RetentionBaselineStore = RetentionBaselineStore()
    ) {
        loadExport = { appVersion, buildNumber in
            guard let onboardingExperiment = onboardingStore.load() else { return nil }
            return UsageReportExport(
                appVersion: appVersion,
                buildNumber: buildNumber,
                onboardingExperiment: onboardingExperiment,
                retentionBaseline: retentionStore.load()
            )
        }
    }

    init(load: @escaping @Sendable (String, String) -> UsageReportExport?) {
        loadExport = load
    }

    func load(appVersion: String, buildNumber: String) -> UsageReportExport? {
        loadExport(appVersion, buildNumber)
    }
}
