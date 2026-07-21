import Foundation
import OSLog

nonisolated protocol AnalyticsRecording: Sendable {
    func record(_ event: AnalyticsEvent) async
}

actor AnalyticsRecorder: AnalyticsRecording {
    static let shared = AnalyticsRecorder(platform: .ios)
    static let widget = AnalyticsRecorder(platform: .widget)
    static let fileName = "analytics-v1.jsonl"
    nonisolated static var defaultFileURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AnalyticsIdentity.appGroupIdentifier
        )?.appending(path: fileName)
    }
    nonisolated static var defaultIsTest: Bool {
#if DEBUG
        true
#else
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
#endif
    }

    private let fileURL: URL?
    private let identity: AnalyticsIdentity
    private let platform: AnalyticsPlatform
    private let isTest: Bool
    private let now: @Sendable () -> Date
    private var sessionID = UUID()
    private var hasRecordedActivation = false
    private let defaults = UserDefaults(suiteName: AnalyticsIdentity.appGroupIdentifier)
    private let logger = Logger(subsystem: "kr.donminzzi.QuestKeeper", category: "Analytics")

    init(
        fileURL: URL? = AnalyticsRecorder.defaultFileURL,
        identity: AnalyticsIdentity = .shared(),
        platform: AnalyticsPlatform,
        isTest: Bool = AnalyticsRecorder.defaultIsTest,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.fileURL = fileURL
        self.identity = identity
        self.platform = platform
        self.isTest = isTest
        self.now = now
    }

    func startSession() {
        sessionID = UUID()
        hasRecordedActivation = false
    }

    func recordActivation(type: String, entrySource: String, startsNewSession: Bool = false) {
        if startsNewSession { startSession() }
        guard !hasRecordedActivation else { return }
        hasRecordedActivation = true
        if defaults?.object(forKey: "analytics-first-activation") == nil {
            defaults?.set(now().timeIntervalSince1970, forKey: "analytics-first-activation")
        }
        record(AnalyticsEvent(name: .appActivated, properties: [
            "activation_type": .string(type),
            "entry_source": .string(entrySource)
        ]))
    }

    func record(_ event: AnalyticsEvent) {
        guard let fileURL else { return }
        let occurredAt = now()
        let context = AnalyticsContext(
            eventID: UUID(),
            occurredAt: occurredAt,
            localDay: Self.localDay(for: occurredAt),
            installationID: identity.installationID,
            sessionID: sessionID,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            platform: platform,
            isTest: isTest
        )
        do {
            var line = try AnalyticsJSON.encoder.encode(AnalyticsEnvelope(event: event, context: context))
            line.append(0x0A)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                _ = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.synchronize()
            try handle.close()
#if DEBUG
            logger.debug("Recorded \(event.name.rawValue, privacy: .public); property keys: \(event.properties.keys.sorted().joined(separator: ","), privacy: .public)")
#endif
        } catch {
            logger.error("Could not persist analytics event \(event.name.rawValue, privacy: .public)")
        }
    }

    func exportURL() -> URL? { fileURL }

    func questKey(for id: UUID) -> String { identity.questKey(for: id) }

    func recordQuestCreated(id: UUID, importance: Importance, deadline: Date, now eventTime: Date) {
        let importanceName = switch importance {
        case .low: "low"
        case .medium: "medium"
        case .high: "high"
        }
        record(AnalyticsEvent(name: .questCreated, properties: [
            "quest_key": .string(identity.questKey(for: id)),
            "importance": .string(importanceName),
            "deadline_bucket": .string(analyticsDeadlineBucket(deadline: deadline, now: eventTime)),
            "creation_source": "editor"
        ]))
    }

    func recordFirstValue(id: UUID) {
        guard defaults?.bool(forKey: "analytics-first-value-recorded") != true else { return }
        defaults?.set(true, forKey: "analytics-first-value-recorded")
        let firstActivation = defaults?.double(forKey: "analytics-first-activation") ?? now().timeIntervalSince1970
        let elapsedSeconds = Int(now().timeIntervalSince1970 - firstActivation)
        record(AnalyticsEvent(name: .firstValueExperienced, properties: [
            "quest_key": .string(identity.questKey(for: id)),
            "elapsed_seconds": .integer(min(max(elapsedSeconds, 0), 86_400)),
            "experience_version": "dungeon_board_v1"
        ]))
    }

    func recordCompletion(id: UUID, source: String, deadline: Date, now eventTime: Date) {
        let isFirst = defaults?.bool(forKey: "analytics-first-completion-recorded") != true
        if isFirst { defaults?.set(true, forKey: "analytics-first-completion-recorded") }
        record(AnalyticsEvent(name: .questCompleted, properties: [
            "quest_key": .string(identity.questKey(for: id)),
            "completion_source": .string(source),
            "deadline_state": .string(analyticsDeadlineBucket(deadline: deadline, now: eventTime)),
            "is_first_completion": .boolean(isFirst)
        ]))
    }

    private static func localDay(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
