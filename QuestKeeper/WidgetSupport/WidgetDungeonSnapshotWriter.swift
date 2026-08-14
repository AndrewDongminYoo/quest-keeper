import Foundation
import OSLog
import WidgetKit

actor WidgetDungeonSnapshotWriter {
    private struct Submission {
        let id: UInt64
        let payload: WidgetDungeonPayload
        let continuation: CheckedContinuation<Bool, Never>
    }

    typealias Save = @Sendable (WidgetDungeonPayload) async throws -> Void
    typealias ReloadAllTimelines = @Sendable () async -> Void
    typealias RetryDelay = @Sendable () async -> Void
    typealias SubmissionAccepted = @Sendable (WidgetDungeonPayload) -> Void

    static let maximumSaveAttempts = 2

    private let save: Save
    private let reloadAllTimelines: ReloadAllTimelines
    private let retryDelay: RetryDelay
    private let onSubmissionAccepted: SubmissionAccepted
    private let logger = Logger(subsystem: "kr.donminzzi.QuestKeeper", category: "WidgetSnapshot")
    private var pendingSubmission: Submission?
    private var activeSubmissionID: UInt64?
    private var latestSubmittedAt = Date.distantPast
    private var isSaving = false
    private var nextSubmissionID: UInt64 = 0

    init(
        snapshotStore: WidgetDungeonSnapshotStore = WidgetDungeonSnapshotStore(),
        reloadAllTimelines: @escaping ReloadAllTimelines = {
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        },
        retryDelay: @escaping RetryDelay = {
            try? await Task.sleep(nanoseconds: 100_000_000)
        },
        onSubmissionAccepted: @escaping SubmissionAccepted = { _ in }
    ) {
        self.save = { payload in
            try snapshotStore.save(payload)
        }
        self.reloadAllTimelines = reloadAllTimelines
        self.retryDelay = retryDelay
        self.onSubmissionAccepted = onSubmissionAccepted
    }

    init(
        save: @escaping Save,
        reloadAllTimelines: @escaping ReloadAllTimelines = {},
        retryDelay: @escaping RetryDelay = {
            try? await Task.sleep(nanoseconds: 100_000_000)
        },
        onSubmissionAccepted: @escaping SubmissionAccepted = { _ in }
    ) {
        self.save = save
        self.reloadAllTimelines = reloadAllTimelines
        self.retryDelay = retryDelay
        self.onSubmissionAccepted = onSubmissionAccepted
    }

    @discardableResult
    func submit(_ payload: WidgetDungeonPayload) async -> Bool {
        guard payload.generatedAt >= latestSubmittedAt else { return false }
        latestSubmittedAt = payload.generatedAt

        return await withCheckedContinuation { continuation in
            nextSubmissionID += 1
            let submission = Submission(
                id: nextSubmissionID,
                payload: payload,
                continuation: continuation
            )
            if let replaced = pendingSubmission {
                replaced.continuation.resume(returning: false)
            }
            pendingSubmission = submission
            onSubmissionAccepted(payload)

            guard !isSaving else { return }
            isSaving = true
            Task { await self.drain() }
        }
    }

    private func drain() async {
        while let submission = pendingSubmission {
            pendingSubmission = nil
            activeSubmissionID = submission.id

            let saved = await saveWithRetry(submission.payload)
            var isLatest = activeSubmissionID == submission.id && pendingSubmission == nil
            if saved, isLatest {
                await reloadAllTimelines()
                isLatest = activeSubmissionID == submission.id && pendingSubmission == nil
            }
            submission.continuation.resume(returning: saved && isLatest)
            activeSubmissionID = nil
        }

        isSaving = false
    }

    private func saveWithRetry(_ payload: WidgetDungeonPayload) async -> Bool {
        for attempt in 1...Self.maximumSaveAttempts {
            do {
                try await save(payload)
                return true
            } catch {
                logger.error("Failed to write widget snapshot attempt \(attempt): \(String(describing: error), privacy: .public)")
                if pendingSubmission != nil {
                    return false
                }
                if attempt < Self.maximumSaveAttempts {
                    await retryDelay()
                    if pendingSubmission != nil {
                        return false
                    }
                }
            }
        }

        logger.error("Dropping widget snapshot after \(Self.maximumSaveAttempts) failed write attempts")
        return false
    }
}
