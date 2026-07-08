import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget dungeon snapshot writer")
struct WidgetDungeonSnapshotWriterTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("writer saves newer payload after an older in-flight write and reloads only once")
    func writerPrefersLatestPayload() async {
        let firstPayload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "first",
                    deadline: now.addingTimeInterval(300),
                    completedAt: nil,
                    importanceRawValue: 1
                )
            ]
        )
        let secondPayload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now.addingTimeInterval(1),
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "second",
                    deadline: now.addingTimeInterval(600),
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )
        let probe = SnapshotWriterProbe()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                if payload == firstPayload {
                    await probe.waitUntilFirstSaveCanFinish()
                }
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                Task {
                    await probe.recordReload()
                }
            }
        )

        let firstTask = Task {
            await writer.submit(firstPayload)
        }

        await probe.waitForFirstSaveToStart()
        await writer.submit(secondPayload)
        await probe.allowFirstSaveToFinish()
        await firstTask.value

        await waitForCondition("writer to save both payloads and reload latest once") {
            let snapshot = await probe.snapshot()
            return snapshot.started == [firstPayload, secondPayload]
                && snapshot.finished == [firstPayload, secondPayload]
                && snapshot.reloadCount == 1
        }

        let snapshot = await probe.snapshot()
        #expect(snapshot.started == [firstPayload, secondPayload])
        #expect(snapshot.finished == [firstPayload, secondPayload])
        #expect(snapshot.reloadCount == 1)
    }

    private func waitForCondition(
        _ description: String,
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollNanoseconds: UInt64 = 10_000_000,
        condition: @escaping @Sendable () async -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while !(await condition()) {
            if DispatchTime.now().uptimeNanoseconds >= deadline {
                Issue.record("Timed out waiting for \(description)")
                return
            }

            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
    }
}

private actor SnapshotWriterProbe {
    private var started: [WidgetDungeonPayload] = []
    private var finished: [WidgetDungeonPayload] = []
    private var reloadCount = 0
    private var firstSaveStartedContinuation: CheckedContinuation<Void, Never>?
    private var firstSaveFinishContinuation: CheckedContinuation<Void, Never>?

    func recordSaveStart(_ payload: WidgetDungeonPayload) {
        started.append(payload)
        firstSaveStartedContinuation?.resume()
        firstSaveStartedContinuation = nil
    }

    func recordSaveFinish(_ payload: WidgetDungeonPayload) {
        finished.append(payload)
    }

    func waitForFirstSaveToStart() async {
        guard started.isEmpty else { return }

        await withCheckedContinuation { continuation in
            firstSaveStartedContinuation = continuation
        }
    }

    func waitUntilFirstSaveCanFinish() async {
        await withCheckedContinuation { continuation in
            firstSaveFinishContinuation = continuation
        }
    }

    func allowFirstSaveToFinish() {
        firstSaveFinishContinuation?.resume()
        firstSaveFinishContinuation = nil
    }

    func recordReload() {
        reloadCount += 1
    }

    func snapshot() -> SnapshotWriterProbeState {
        SnapshotWriterProbeState(
            started: started,
            finished: finished,
            reloadCount: reloadCount
        )
    }
}

private struct SnapshotWriterProbeState: Sendable {
    let started: [WidgetDungeonPayload]
    let finished: [WidgetDungeonPayload]
    let reloadCount: Int
}
