import Foundation
import SwiftData

nonisolated enum OnboardingExperiment {
    static let key = "and-34-first-value-v1"
}

nonisolated enum OnboardingExperimentVariant: String, Codable, CaseIterable, Sendable {
    case control
    case guided
}

@Model
final class ExperimentAssignment {
    static let currentSchemaVersion = 1

    private(set) var schemaVersion: Int
    private(set) var experimentKey: String
    private(set) var installationID: UUID
    private(set) var variantRawValue: String
    private(set) var assignedAt: Date

    init(
        schemaVersion: Int = currentSchemaVersion,
        experimentKey: String = OnboardingExperiment.key,
        installationID: UUID,
        variant: OnboardingExperimentVariant,
        assignedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.experimentKey = experimentKey
        self.installationID = installationID
        self.variantRawValue = variant.rawValue
        self.assignedAt = assignedAt
    }

    var snapshot: ExperimentAssignmentSnapshot {
        ExperimentAssignmentSnapshot(
            schemaVersion: schemaVersion,
            experimentKey: experimentKey,
            installationID: installationID,
            variantRawValue: variantRawValue,
            assignedAt: assignedAt
        )
    }
}

nonisolated struct ExperimentAssignmentSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let experimentKey: String
    let installationID: UUID
    let variantRawValue: String
    let assignedAt: Date

    var variant: OnboardingExperimentVariant? {
        OnboardingExperimentVariant(rawValue: variantRawValue)
    }
}
