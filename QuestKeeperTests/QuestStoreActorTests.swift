//
//  QuestStoreActorTests.swift
//  QuestKeeperTests
//
//  Spec 009 — the widget's completion mutation. Single-process, in-memory: proves the write logic
//  and idempotence (cross-process visibility is a separate manual/spike gate, not unit-testable).
//

import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct QuestStoreActorTests {
    private func container() throws -> ModelContainer {
        let schema = Schema([Quest.self, RetentionInstallation.self, RetentionEvent.self])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    @Test("complete writes completedAt for a pending quest")
    func completesPending() async throws {
        let c = try container()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let quest = Quest(title: "물 마시기", deadline: now.addingTimeInterval(3600), importance: .medium)
        c.mainContext.insert(quest)
        try c.mainContext.save()
        let id = quest.id

        let wrote = try await QuestStoreActor(modelContainer: c).complete(id: id, now: now)
        let duplicateWrote = try await QuestStoreActor(modelContainer: c).complete(id: id, now: now)

        #expect(wrote == true)
        #expect(duplicateWrote == false)
        let fresh = ModelContext(c)
        let fetched = try fresh.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })).first
        #expect(fetched?.completedAt == now)
        let events = try fresh.fetch(FetchDescriptor<RetentionEvent>())
        #expect(events.count == 1)
        #expect(events.first?.snapshot.name == .questCompleted)
        #expect(events.first?.snapshot.source == .widget)
    }

    @Test("complete is idempotent on an already-completed quest")
    func idempotent() async throws {
        let c = try container()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let alreadyDone = now.addingTimeInterval(-10)
        let quest = Quest(title: "x", deadline: now, importance: .low, completedAt: alreadyDone)
        c.mainContext.insert(quest)
        try c.mainContext.save()
        let id = quest.id

        let wrote = try await QuestStoreActor(modelContainer: c).complete(id: id, now: now)

        #expect(wrote == false)
        let fresh = ModelContext(c)
        let fetched = try fresh.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })).first
        #expect(fetched?.completedAt == alreadyDone) // unchanged
        #expect(try fresh.fetch(FetchDescriptor<RetentionEvent>()).isEmpty)
    }

    @Test("complete is a no-op for a missing id")
    func missingIsNoOp() async throws {
        let c = try container()
        let wrote = try await QuestStoreActor(modelContainer: c).complete(id: UUID(), now: .now)
        #expect(wrote == false)
        let fresh = ModelContext(c)
        #expect(try fresh.fetch(FetchDescriptor<RetentionEvent>()).isEmpty)
    }
}
