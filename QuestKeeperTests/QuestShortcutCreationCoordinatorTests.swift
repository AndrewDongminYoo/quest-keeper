import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct QuestShortcutCreationCoordinatorTests {
    @Test("creation succeeds and reports successful follow-ups")
    func createsAndRunsFollowUps() async throws {
        let container = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var scheduledSnapshot: QuestSnapshot?
        var updatedPayload: WidgetDungeonPayload?
        let coordinator = QuestShortcutCreationCoordinator(
            modelContainer: container,
            scheduleNotifications: { snapshot, _, _ in
                scheduledSnapshot = snapshot
                return .allowed
            },
            updateWidgetSnapshot: { payload in
                updatedPayload = payload
                return true
            }
        )

        let outcome = try await coordinator.create(
            input: try QuestCreationInput(
                title: "Shortcut quest",
                details: "Details",
                deadline: now.addingTimeInterval(3_600),
                importance: .high
            ),
            now: now,
            locale: Locale(identifier: "ko")
        )

        #expect(scheduledSnapshot?.id == outcome.questID)
        #expect(updatedPayload?.quests.contains { $0.id == outcome.questID } == true)
        #expect(outcome.requiresNotificationPermission == false)
        #expect(outcome.followUpFailures.isEmpty)
    }

    @Test("denied notification permission does not roll back creation")
    func deniedPermissionIsCreatedWithGuidance() async throws {
        let container = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let coordinator = makeCoordinator(
            container: container,
            authorization: .denied,
            widgetUpdated: true
        )

        let outcome = try await coordinator.create(input: try shortcutInput(now: now), now: now)

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Quest>()) == 1)
        #expect(outcome.requiresNotificationPermission)
        #expect(outcome.followUpFailures.isEmpty)
    }

    @Test("follow-up failures remain a successful Quest creation")
    func reportsPartialFailureAfterCommit() async throws {
        let container = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let coordinator = makeCoordinator(
            container: container,
            authorization: .unavailable,
            widgetUpdated: false
        )

        let outcome = try await coordinator.create(input: try shortcutInput(now: now), now: now)

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Quest>()) == 1)
        #expect(outcome.followUpFailures == [.notifications, .widgetSnapshot])
    }

    @Test("widget snapshot is timestamped after notification work")
    func widgetSnapshotUsesPostNotificationTimestamp() async throws {
        let container = try makeContainer()
        let invocationDate = Date(timeIntervalSinceReferenceDate: 1)
        let competingPayload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: invocationDate.addingTimeInterval(1),
            quests: []
        )
        let probe = QuestShortcutWidgetSnapshotProbe()
        let writer = WidgetDungeonSnapshotWriter(save: { payload in
            await probe.record(payload)
        })
        var competingSubmissionAccepted = false
        let coordinator = QuestShortcutCreationCoordinator(
            modelContainer: container,
            scheduleNotifications: { _, _, _ in
                competingSubmissionAccepted = await writer.submit(competingPayload)
                return .allowed
            },
            updateWidgetSnapshot: { payload in
                await writer.submit(payload)
            }
        )

        let outcome = try await coordinator.create(
            input: try shortcutInput(now: invocationDate),
            now: invocationDate
        )

        let savedPayloads = await probe.snapshot()
        #expect(competingSubmissionAccepted)
        #expect(outcome.didUpdateWidgetSnapshot)
        #expect(savedPayloads.last?.quests.contains { $0.id == outcome.questID } == true)
    }

    @Test("container refresh sends the next shortcut write only to the refreshed store")
    func usesRefreshedContainer() async throws {
        let oldContainer = try makeContainer()
        let refreshedContainer = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let coordinator = makeCoordinator(
            container: oldContainer,
            authorization: .allowed,
            widgetUpdated: true
        )
        coordinator.updateModelContainer(refreshedContainer)

        _ = try await coordinator.create(input: try shortcutInput(now: now), now: now)

        #expect(try ModelContext(oldContainer).fetchCount(FetchDescriptor<Quest>()) == 0)
        #expect(try ModelContext(refreshedContainer).fetchCount(FetchDescriptor<Quest>()) == 1)
    }

    @Test("identical shortcut invocations create distinct Quests")
    func identicalInvocationsCreateDistinctQuests() async throws {
        let container = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let coordinator = makeCoordinator(
            container: container,
            authorization: .allowed,
            widgetUpdated: true
        )
        let input = try shortcutInput(now: now)

        let first = try await coordinator.create(input: input, now: now)
        let second = try await coordinator.create(input: input, now: now)

        #expect(first.questID != second.questID)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Quest>()) == 2)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Quest.self, RetentionInstallation.self, RetentionEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        container.mainContext.insert(RetentionInstallation(
            installationID: UUID(),
            measurementStartedAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
        ))
        try container.mainContext.save()
        return container
    }

    private func makeCoordinator(
        container: ModelContainer,
        authorization: QuestNotificationAuthorization,
        widgetUpdated: Bool
    ) -> QuestShortcutCreationCoordinator {
        QuestShortcutCreationCoordinator(
            modelContainer: container,
            scheduleNotifications: { _, _, _ in authorization },
            updateWidgetSnapshot: { _ in widgetUpdated }
        )
    }

    private func shortcutInput(now: Date) throws -> QuestCreationInput {
        try QuestCreationInput(
            title: "Shortcut quest",
            details: "Details",
            deadline: now.addingTimeInterval(3_600),
            importance: .high
        )
    }
}

private actor QuestShortcutWidgetSnapshotProbe {
    private var savedPayloads: [WidgetDungeonPayload] = []

    func record(_ payload: WidgetDungeonPayload) {
        savedPayloads.append(payload)
    }

    func snapshot() -> [WidgetDungeonPayload] {
        savedPayloads
    }
}
