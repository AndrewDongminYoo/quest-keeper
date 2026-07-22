import Foundation
import OSLog
import SwiftData

nonisolated enum ExperimentEnrollmentResult: Equatable, Sendable {
    case enrolled(ExperimentAssignmentSnapshot)
    case ineligible
    case failed

    var assignment: ExperimentAssignmentSnapshot? {
        guard case let .enrolled(assignment) = self else { return nil }
        return assignment
    }
}

@MainActor
enum ExperimentAssignmentRecorder {
    private static let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "OnboardingExperiment"
    )

    static func enrollIfEligible(
        at assignedAt: Date,
        in context: ModelContext,
        installationIDProvider: () throws -> UUID = defaultInstallationID,
        variantSelector: () -> OnboardingExperimentVariant = randomVariant
    ) -> ExperimentEnrollmentResult {
        do {
            let assignments = try context.fetch(FetchDescriptor<ExperimentAssignment>())
                .filter { $0.experimentKey == OnboardingExperiment.key }
            if !assignments.isEmpty {
                return existingEnrollment(assignments, in: context)
            }

            guard try context.fetchCount(FetchDescriptor<RetentionInstallation>()) == 0,
                  try context.fetchCount(FetchDescriptor<Quest>()) == 0 else {
                return .ineligible
            }

            let installationID = try installationIDProvider()
            let installation = RetentionInstallation(
                installationID: installationID,
                measurementStartedAt: assignedAt
            )
            let assignment = ExperimentAssignment(
                installationID: installationID,
                variant: variantSelector(),
                assignedAt: assignedAt
            )
            context.insert(installation)
            context.insert(assignment)

            do {
                try context.save()
                return .enrolled(assignment.snapshot)
            } catch {
                context.delete(assignment)
                context.delete(installation)
                throw error
            }
        } catch {
            logger.error("Failed to enroll onboarding experiment: \(String(describing: error), privacy: .public)")
            return .failed
        }
    }

    private static func existingEnrollment(
        _ assignments: [ExperimentAssignment],
        in context: ModelContext
    ) -> ExperimentEnrollmentResult {
        guard assignments.count == 1,
              let assignment = assignments.first,
              assignment.schemaVersion == ExperimentAssignment.currentSchemaVersion,
              assignment.snapshot.variant != nil else {
            return .failed
        }

        do {
            let installations = try context.fetch(FetchDescriptor<RetentionInstallation>())
            guard installations.count == 1,
                  installations.first?.installationID == assignment.installationID else {
                return .failed
            }
            return .enrolled(assignment.snapshot)
        } catch {
            logger.error("Failed to read onboarding enrollment: \(String(describing: error), privacy: .public)")
            return .failed
        }
    }

    nonisolated private static func defaultInstallationID() throws -> UUID {
        try RetentionInstallationIdentityStore.appGroup().loadOrCreate()
    }

    nonisolated private static func randomVariant() -> OnboardingExperimentVariant {
        Bool.random() ? .control : .guided
    }
}
