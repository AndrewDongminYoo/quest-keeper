import AppIntents
import Foundation

nonisolated enum ShortcutQuestImportance: String, Sendable {
    case low
    case medium
    case high

    var value: Importance {
        switch self {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
}

nonisolated struct ShortcutQuestImportanceOptionsProvider: DynamicOptionsProvider {
    typealias Result = IntentItemCollection<String>
    typealias DefaultValue = String

    func results() async throws -> Result {
        Result(sections: [IntentItemSection(items: [
            IntentItem("low", title: LocalizedStringResource(
                "appIntent.createQuest.importance.low",
                defaultValue: "낮음"
            )),
            IntentItem("medium", title: LocalizedStringResource(
                "appIntent.createQuest.importance.medium",
                defaultValue: "보통"
            )),
            IntentItem("high", title: LocalizedStringResource(
                "appIntent.createQuest.importance.high",
                defaultValue: "높음"
            )),
        ])])
    }
}

nonisolated enum CreateQuestIntentDialogKind: Equatable, Sendable {
    case created
    case createdNeedsNotificationPermission
    case createdWithFollowUpWarning
    case createdWithFollowUpWarningAndNotificationPermission

    static func make(
        authorization: QuestNotificationAuthorization,
        followUpFailures: Set<QuestShortcutFollowUpFailure>
    ) -> CreateQuestIntentDialogKind {
        let needsPermission = authorization == .notDetermined || authorization == .denied
        switch (!followUpFailures.isEmpty, needsPermission) {
        case (false, false): return .created
        case (false, true): return .createdNeedsNotificationPermission
        case (true, false): return .createdWithFollowUpWarning
        case (true, true): return .createdWithFollowUpWarningAndNotificationPermission
        }
    }

    var resource: LocalizedStringResource {
        switch self {
        case .created:
            LocalizedStringResource("appIntent.createQuest.result.created", defaultValue: "퀘스트를 생성했습니다.")
        case .createdNeedsNotificationPermission:
            LocalizedStringResource(
                "appIntent.createQuest.result.permissionRequired",
                defaultValue: "퀘스트를 생성했습니다. 알림은 TODO Slayer에서 권한을 허용하면 받을 수 있습니다."
            )
        case .createdWithFollowUpWarning:
            LocalizedStringResource(
                "appIntent.createQuest.result.partial",
                defaultValue: "퀘스트는 생성했지만 일부 후속 작업을 완료하지 못했습니다."
            )
        case .createdWithFollowUpWarningAndNotificationPermission:
            LocalizedStringResource(
                "appIntent.createQuest.result.partialAndPermissionRequired",
                defaultValue: "퀘스트는 생성했지만 일부 후속 작업을 완료하지 못했고 알림 권한도 필요합니다."
            )
        }
    }
}

nonisolated enum CreateQuestIntentError: LocalizedError, Equatable, Sendable {
    case emptyTitle
    case deadlineNotInFuture
    case invalidImportance
    case persistenceFailed

    var resource: LocalizedStringResource {
        switch self {
        case .emptyTitle:
            LocalizedStringResource(
                "appIntent.createQuest.error.emptyTitle",
                defaultValue: "제목을 입력해주세요."
            )
        case .deadlineNotInFuture:
            LocalizedStringResource(
                "appIntent.createQuest.error.deadlineNotInFuture",
                defaultValue: "마감은 현재 시간 이후여야 합니다."
            )
        case .invalidImportance:
            LocalizedStringResource(
                "appIntent.createQuest.error.invalidImportance",
                defaultValue: "중요도는 낮음, 보통, 높음 중에서 선택해주세요."
            )
        case .persistenceFailed:
            LocalizedStringResource(
                "appIntent.createQuest.error.persistenceFailed",
                defaultValue: "퀘스트를 생성하지 못했습니다. 다시 시도해주세요."
            )
        }
    }

    var errorDescription: String? {
        AppStrings.resolve(resource, locale: .current)
    }
}

struct CreateQuestIntent: AppIntent {
    static let title = LocalizedStringResource(
        "appIntent.createQuest.title",
        defaultValue: "퀘스트 생성"
    )
    static let description = IntentDescription(LocalizedStringResource(
        "appIntent.createQuest.description",
        defaultValue: "TODO Slayer에 새 퀘스트를 생성합니다."
    ))
    static let supportedModes: IntentModes = .background

    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.title",
        defaultValue: "제목"
    )) var title: String
    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.details",
        defaultValue: "설명"
    )) var details: String?
    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.deadline",
        defaultValue: "마감"
    )) var deadline: Date?
    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.importance",
        defaultValue: "중요도"
    ), optionsProvider: ShortcutQuestImportanceOptionsProvider()) var importance: String?

    @Dependency private var coordinator: QuestShortcutCreationCoordinator

    static var parameterSummary: some ParameterSummary {
        Summary("Create quest") {
            \.$title
            \.$details
            \.$deadline
            \.$importance
        }
    }

    init() {}

    nonisolated static func creationInput(
        title: String,
        details: String?,
        deadline: Date?,
        importance: String?,
        now: Date
    ) throws -> QuestCreationInput {
        let resolvedImportance: Importance?
        if let importance {
            guard let shortcutImportance = ShortcutQuestImportance(rawValue: importance) else {
                throw CreateQuestIntentError.invalidImportance
            }
            resolvedImportance = shortcutImportance.value
        } else {
            resolvedImportance = nil
        }

        return try QuestCreationInput.shortcut(
            title: title,
            details: details,
            deadline: deadline,
            importance: resolvedImportance,
            now: now
        )
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date.now
        let input: QuestCreationInput
        do {
            input = try Self.creationInput(
                title: title,
                details: details,
                deadline: deadline,
                importance: importance,
                now: now
            )
        } catch QuestCreationInputError.emptyTitle {
            throw CreateQuestIntentError.emptyTitle
        } catch QuestCreationInputError.deadlineNotInFuture {
            throw CreateQuestIntentError.deadlineNotInFuture
        }

        let outcome: QuestShortcutCreationOutcome
        do {
            outcome = try await coordinator.create(input: input, now: now, locale: .current)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            throw CreateQuestIntentError.persistenceFailed
        }
        let kind = CreateQuestIntentDialogKind.make(
            authorization: outcome.notificationAuthorization,
            followUpFailures: outcome.followUpFailures
        )
        return .result(dialog: IntentDialog(kind.resource))
    }
}
