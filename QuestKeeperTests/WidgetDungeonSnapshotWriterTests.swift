import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget dungeon snapshot writer")
struct WidgetDungeonSnapshotWriterTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("failed older write yields false before a newer write succeeds")
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
        let (acceptedPayloads, acceptedPayloadContinuation) = AsyncStream<WidgetDungeonPayload>.makeStream()
        var acceptedPayloadIterator = acceptedPayloads.makeAsyncIterator()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                if payload == firstPayload {
                    await probe.waitUntilFirstSaveCanFinish()
                    struct SaveFailure: Error {}
                    throw SaveFailure()
                }
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.recordReload()
            },
            onSubmissionAccepted: { payload in
                acceptedPayloadContinuation.yield(payload)
            }
        )

        let firstTask = Task { await writer.submit(firstPayload) }

        await probe.waitForFirstSaveToStart()
        #expect(await acceptedPayloadIterator.next() == firstPayload)
        let secondTask = Task { await writer.submit(secondPayload) }
        #expect(await acceptedPayloadIterator.next() == secondPayload)
        acceptedPayloadContinuation.finish()
        await probe.allowFirstSaveToFinish()
        let firstResult = await firstTask.value
        let secondResult = await secondTask.value

        await waitForCondition("writer to save both payloads and reload latest once") {
            let snapshot = await probe.snapshot()
            return snapshot.started == [firstPayload, secondPayload]
                && snapshot.finished == [secondPayload]
                && snapshot.reloadCount == 1
        }

        let snapshot = await probe.snapshot()
        #expect(firstResult == false)
        #expect(secondResult == true)
        #expect(snapshot.started == [firstPayload, secondPayload])
        #expect(snapshot.finished == [secondPayload])
        #expect(snapshot.reloadCount == 1)
    }

    @Test("writer replaces a pending submission even when timestamps are equal")
    func writerReplacesPendingSubmission() async {
        let activePayload = payload(title: "active", generatedAt: now)
        let middlePayload = payload(title: "middle", generatedAt: now.addingTimeInterval(1))
        let latestPayload = payload(title: "latest", generatedAt: now.addingTimeInterval(1))
        let probe = SnapshotWriterProbe()
        let (acceptedPayloads, acceptedPayloadContinuation) = AsyncStream<WidgetDungeonPayload>.makeStream()
        var acceptedPayloadIterator = acceptedPayloads.makeAsyncIterator()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                if payload == activePayload {
                    await probe.waitUntilFirstSaveCanFinish()
                }
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.recordReload()
            },
            onSubmissionAccepted: { payload in
                acceptedPayloadContinuation.yield(payload)
            }
        )

        let activeTask = Task { await writer.submit(activePayload) }
        await probe.waitForFirstSaveToStart()
        #expect(await acceptedPayloadIterator.next() == activePayload)
        let middleTask = Task { await writer.submit(middlePayload) }
        #expect(await acceptedPayloadIterator.next() == middlePayload)
        let latestTask = Task { await writer.submit(latestPayload) }
        #expect(await acceptedPayloadIterator.next() == latestPayload)
        acceptedPayloadContinuation.finish()
        await probe.allowFirstSaveToFinish()

        let activeResult = await activeTask.value
        let middleResult = await middleTask.value
        let latestResult = await latestTask.value
        await waitForCondition("writer to save only active and latest payloads") {
            let snapshot = await probe.snapshot()
            return snapshot.finished == [activePayload, latestPayload]
                && snapshot.reloadCount == 1
        }

        let snapshot = await probe.snapshot()
        #expect(activeResult == false)
        #expect(middleResult == false)
        #expect(latestResult == true)
        #expect(snapshot.started == [activePayload, latestPayload])
        #expect(snapshot.finished == [activePayload, latestPayload])
        #expect(snapshot.reloadCount == 1)
    }

    @Test("writer reports stale payload false without saving or reloading")
    func writerIgnoresOlderPayloadSubmittedAfterNewerPayload() async {
        let oldPayload = payload(title: "old", generatedAt: now)
        let newPayload = payload(title: "new", generatedAt: now.addingTimeInterval(1))
        let probe = SnapshotWriterProbe()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.recordReload()
            }
        )

        let newResult = await writer.submit(newPayload)
        let oldResult = await writer.submit(oldPayload)

        await waitForCondition("writer to ignore stale older payload") {
            let snapshot = await probe.snapshot()
            return snapshot.finished == [newPayload]
                && snapshot.reloadCount == 1
        }

        let snapshot = await probe.snapshot()
        #expect(newResult == true)
        #expect(oldResult == false)
        #expect(snapshot.started == [newPayload])
        #expect(snapshot.finished == [newPayload])
        #expect(snapshot.reloadCount == 1)
    }

    @Test("writer retries a failed latest payload once")
    func writerRetriesFailedLatestPayloadOnce() async {
        let latestPayload = payload(title: "retry", generatedAt: now)
        let probe = SnapshotWriterProbe()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                if await probe.saveAttemptCount(for: payload) == 1 {
                    struct SaveFailure: Error {}
                    throw SaveFailure()
                }
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.recordReload()
            }
        )

        let result = await writer.submit(latestPayload)

        await waitForCondition("writer to retry failed latest payload") {
            let snapshot = await probe.snapshot()
            return snapshot.started == [latestPayload, latestPayload]
                && snapshot.finished == [latestPayload]
                && snapshot.reloadCount == 1
        }

        let snapshot = await probe.snapshot()
        #expect(result == true)
        #expect(snapshot.started == [latestPayload, latestPayload])
        #expect(snapshot.finished == [latestPayload])
        #expect(snapshot.reloadCount == 1)
    }

    @Test("writer aborts an older retry when a newer submission arrives during retry delay")
    func writerRechecksPendingSubmissionAfterRetryDelay() async {
        let oldPayload = payload(title: "old", generatedAt: now)
        let newPayload = payload(title: "new", generatedAt: now.addingTimeInterval(1))
        let probe = SnapshotWriterProbe()
        let (acceptedPayloads, acceptedPayloadContinuation) = AsyncStream<WidgetDungeonPayload>.makeStream()
        var acceptedPayloadIterator = acceptedPayloads.makeAsyncIterator()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                if payload == oldPayload {
                    struct SaveFailure: Error {}
                    throw SaveFailure()
                }
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.recordReload()
            },
            retryDelay: {
                await probe.waitInRetryDelay()
            },
            onSubmissionAccepted: { payload in
                acceptedPayloadContinuation.yield(payload)
            }
        )

        let oldTask = Task { await writer.submit(oldPayload) }
        #expect(await acceptedPayloadIterator.next() == oldPayload)
        await probe.waitForRetryDelayToStart()
        let newTask = Task { await writer.submit(newPayload) }
        #expect(await acceptedPayloadIterator.next() == newPayload)
        acceptedPayloadContinuation.finish()
        await probe.allowRetryDelayToFinish()

        let oldResult = await oldTask.value
        let newResult = await newTask.value
        await waitForCondition("writer to skip the old retry and save the newer payload") {
            let snapshot = await probe.snapshot()
            return snapshot.finished == [newPayload]
                && snapshot.reloadCount == 1
        }

        let snapshot = await probe.snapshot()
        #expect(oldResult == false)
        #expect(newResult == true)
        #expect(snapshot.started == [oldPayload, newPayload])
        #expect(snapshot.finished == [newPayload])
        #expect(snapshot.reloadCount == 1)
    }

    @Test("writer returns true only after the latest reload finishes")
    func writerAwaitsReloadBeforeReturningSuccess() async {
        let latestPayload = payload(title: "latest", generatedAt: now)
        let probe = SnapshotWriterProbe()
        let resultProbe = SubmissionResultProbe()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.waitInReload()
            }
        )

        let submitTask = Task {
            let result = await writer.submit(latestPayload)
            await resultProbe.record(result)
            return result
        }

        await probe.waitForReloadToStart()
        #expect(await resultProbe.current() == nil)
        await probe.allowReloadToFinish()

        #expect(await submitTask.value == true)
        #expect(await resultProbe.current() == true)
        let snapshot = await probe.snapshot()
        #expect(snapshot.started == [latestPayload])
        #expect(snapshot.finished == [latestPayload])
        #expect(snapshot.reloadCount == 1)
    }

    @Test("writer reports an older reload false when a newer submission arrives")
    func writerRechecksLatestSubmissionAfterReload() async {
        let oldPayload = payload(title: "old", generatedAt: now)
        let newPayload = payload(title: "new", generatedAt: now.addingTimeInterval(1))
        let probe = SnapshotWriterProbe()
        let oldResultProbe = SubmissionResultProbe()
        let (acceptedPayloads, acceptedPayloadContinuation) = AsyncStream<WidgetDungeonPayload>.makeStream()
        var acceptedPayloadIterator = acceptedPayloads.makeAsyncIterator()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.waitInReload()
            },
            onSubmissionAccepted: { payload in
                acceptedPayloadContinuation.yield(payload)
            }
        )

        let oldTask = Task {
            let result = await writer.submit(oldPayload)
            await oldResultProbe.record(result)
            return result
        }
        #expect(await acceptedPayloadIterator.next() == oldPayload)
        await probe.waitForReloadToStart()
        #expect(await oldResultProbe.current() == nil)

        let newTask = Task { await writer.submit(newPayload) }
        #expect(await acceptedPayloadIterator.next() == newPayload)
        acceptedPayloadContinuation.finish()
        await probe.allowReloadToFinish()

        #expect(await oldTask.value == false)
        #expect(await newTask.value == true)
        let snapshot = await probe.snapshot()
        #expect(snapshot.started == [oldPayload, newPayload])
        #expect(snapshot.finished == [oldPayload, newPayload])
        #expect(snapshot.reloadCount == 2)
    }

    @Test("writer delays retry and recovers after permanent failure")
    func writerDelaysRetryAndRecoversAfterPermanentFailure() async {
        let failedPayload = payload(title: "fail", generatedAt: now)
        let recoveryPayload = payload(title: "recover", generatedAt: now.addingTimeInterval(1))
        let probe = SnapshotWriterProbe()
        let writer = WidgetDungeonSnapshotWriter(
            save: { payload in
                await probe.recordSaveStart(payload)
                if payload == failedPayload {
                    struct SaveFailure: Error {}
                    throw SaveFailure()
                }
                await probe.recordSaveFinish(payload)
            },
            reloadAllTimelines: {
                await probe.recordReload()
            },
            retryDelay: {
                await probe.recordRetryDelay()
            }
        )

        let expectedStarts = Array(
            repeating: failedPayload,
            count: WidgetDungeonSnapshotWriter.maximumSaveAttempts
        ) + [recoveryPayload]
        let expectedRetryDelayCount = WidgetDungeonSnapshotWriter.maximumSaveAttempts - 1

        let failedResult = await writer.submit(failedPayload)

        let failedSnapshot = await probe.snapshot()
        #expect(failedResult == false)
        #expect(failedSnapshot.started == Array(
            repeating: failedPayload,
            count: WidgetDungeonSnapshotWriter.maximumSaveAttempts
        ))
        #expect(failedSnapshot.reloadCount == 0)

        let recoveryResult = await writer.submit(recoveryPayload)

        await waitForCondition("writer to recover after permanent failure") {
            let snapshot = await probe.snapshot()
            return snapshot.started == expectedStarts
                && snapshot.finished == [recoveryPayload]
                && snapshot.reloadCount == 1
                && snapshot.retryDelayCount == expectedRetryDelayCount
        }

        let snapshot = await probe.snapshot()
        #expect(recoveryResult == true)
        #expect(snapshot.started == expectedStarts)
        #expect(snapshot.finished == [recoveryPayload])
        #expect(snapshot.reloadCount == 1)
        #expect(snapshot.retryDelayCount == expectedRetryDelayCount)
    }

    private func payload(title: String, generatedAt: Date) -> WidgetDungeonPayload {
        WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: generatedAt,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: title,
                    deadline: generatedAt.addingTimeInterval(300),
                    completedAt: nil,
                    importanceRawValue: 1
                )
            ]
        )
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
    private var retryDelayStartedContinuation: CheckedContinuation<Void, Never>?
    private var retryDelayFinishContinuation: CheckedContinuation<Void, Never>?
    private var reloadStartedContinuation: CheckedContinuation<Void, Never>?
    private var reloadFinishContinuation: CheckedContinuation<Void, Never>?

    func recordSaveStart(_ payload: WidgetDungeonPayload) {
        started.append(payload)
        firstSaveStartedContinuation?.resume()
        firstSaveStartedContinuation = nil
    }

    func saveAttemptCount(for payload: WidgetDungeonPayload) -> Int {
        started.filter { $0 == payload }.count
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

    func recordRetryDelay() {
        retryDelayCount += 1
    }

    func waitInRetryDelay() async {
        retryDelayCount += 1
        retryDelayStartedContinuation?.resume()
        retryDelayStartedContinuation = nil

        await withCheckedContinuation { continuation in
            retryDelayFinishContinuation = continuation
        }
    }

    func waitForRetryDelayToStart() async {
        guard retryDelayCount == 0 else { return }

        await withCheckedContinuation { continuation in
            retryDelayStartedContinuation = continuation
        }
    }

    func allowRetryDelayToFinish() {
        retryDelayFinishContinuation?.resume()
        retryDelayFinishContinuation = nil
    }

    func waitInReload() async {
        reloadCount += 1
        guard reloadCount == 1 else { return }
        reloadStartedContinuation?.resume()
        reloadStartedContinuation = nil

        await withCheckedContinuation { continuation in
            reloadFinishContinuation = continuation
        }
    }

    func waitForReloadToStart() async {
        guard reloadCount == 0 else { return }

        await withCheckedContinuation { continuation in
            reloadStartedContinuation = continuation
        }
    }

    func allowReloadToFinish() {
        reloadFinishContinuation?.resume()
        reloadFinishContinuation = nil
    }

    func snapshot() -> SnapshotWriterProbeState {
        SnapshotWriterProbeState(
            started: started,
            finished: finished,
            reloadCount: reloadCount,
            retryDelayCount: retryDelayCount
        )
    }

    private var retryDelayCount = 0
}

private struct SnapshotWriterProbeState: Sendable {
    let started: [WidgetDungeonPayload]
    let finished: [WidgetDungeonPayload]
    let reloadCount: Int
    let retryDelayCount: Int
}

private actor SubmissionResultProbe {
    private var result: Bool?

    func record(_ result: Bool) {
        self.result = result
    }

    func current() -> Bool? {
        result
    }
}
