import SwiftUI

struct HomeDungeonBoardView: View {
    @Environment(\.tipJarStore) private var tipJarStore
    @AppStorage(HeroAppearance.StorageKey.gender) private var heroGenderRawValue = HeroAppearance.default.gender.rawValue
    @AppStorage(HeroAppearance.StorageKey.hairColor) private var heroHairColorRawValue = HeroAppearance.default.hairColor.rawValue
    @Binding var presentedSheet: HomeDungeonSheet?

    let state: HeroState
    let isMourning: Bool
    let allQuests: [Quest]
    let pending: [Quest]
    let dailyGraves: [Quest]
    let newlyMissedQuestIDs: Set<UUID>
    let escalatedQuestIDs: Set<UUID>
    let now: Date
    let storeFailedToOpen: Bool
    /// A write the store refused. Separate from `storeFailedToOpen`: the store opened fine and is
    /// rejecting saves, so the board is showing on-disk truth rather than an ephemeral copy.
    let lastCommitFailed: Bool
    let notificationPermissionAction: QuestNotificationPermissionAction?
    let notificationAuthorization: QuestNotificationAuthorization?
    let reengagementSettings: ReengagementReminderSettings
    let hasCreatedQuest: Bool
    let onboardingPresentation: OnboardingFlowPresentation
    let dailyFocusPresentation: DailyFocusPresentationState
    let recoveryPresentation: RecoveryCardPresentation?
    let visibleRoutines: [RoutineRule]
    let hasRoutineRules: Bool
    /// `nil` while the week the card would review is already acknowledged, or while the recovery
    /// card owns the board — see `docs/specs/026-weekly-review.md`.
    let weeklyReview: WeeklyReview?
    let onCreate: () -> Void
    let onStartGuidedQuest: () -> Void
    let onDeferOnboarding: () -> Void
    let onConfirmDailyFocus: ([UUID]) -> Void
    let onEditDailyFocus: ([UUID], DailyFocusSelectionKind) -> Void
    let onConfirmRecoveryQuest: (UUID) -> Bool
    let onChooseRecoveryFocus: () -> Void
    let onCreateRecoveryQuest: () -> Void
    let onDismissRecovery: () -> Void
    let onPlanWeek: () -> Void
    let onDismissWeeklyReview: () -> Void
    let onSaveReengagementSettings: (ReengagementReminderSettings) -> Void
    let onOpenNotificationSettings: () -> Void
    let onComplete: (Quest, Date) -> Void
    let onDelete: (Quest) -> Void
    let onOpenDetail: (Quest) -> Void
    let onCreateRoutine: () -> Void
    let onManageRoutines: () -> Void
    let onCompleteRoutine: (RoutineRule) -> Void
    let onSheetDismissed: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            DungeonBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    BoardHUD(
                        state: state,
                        isMourning: isMourning,
                        heroAppearance: heroAppearance,
                        onCreate: onCreate,
                        onEditAppearance: { presentedSheet = .appearance },
                        onOpenAbout: { presentedSheet = .about },
                        onOpenHallOfFame: { presentedSheet = .hallOfFame },
                        onOpenReengagementSettings: { presentedSheet = .reengagement }
                    )
                    if storeFailedToOpen {
                        StoreFailureBanner()
                    }
                    // 권한 안내는 재방문 알림 설정 시트로 보내는데, 첫 퀘스트 전에는 그 시트의 토글이
                    // 비활성이라 안내대로 할 수 있는 일이 없다. 거부 상태의 시스템 설정 경로는 그대로 둔다.
                    if let notificationPermissionAction,
                       notificationPermissionAction == .openSettings || hasCreatedQuest {
                        NotificationPermissionBanner(action: notificationPermissionAction) {
                            switch notificationPermissionAction {
                            case .requestAuthorization:
                                presentedSheet = .reengagement
                            case .openSettings:
                                onOpenNotificationSettings()
                            }
                        }
                    }
                    if let weeklyReview {
                        WeeklyReviewCard(
                            review: weeklyReview,
                            onPlan: onPlanWeek,
                            onDismiss: onDismissWeeklyReview
                        )
                    }
                    if let recoveryPresentation {
                        RecoveryCardView(
                            presentation: recoveryPresentation,
                            quest: recoveryQuest(for: recoveryPresentation),
                            now: now,
                            onConfirmSingleQuest: onConfirmRecoveryQuest,
                            onChooseToday: onChooseRecoveryFocus,
                            onCreateQuest: onCreateRecoveryQuest,
                            onDismiss: onDismissRecovery
                        )
                    }
                    if onboardingPresentation == .guidedOffer {
                        GuidedOnboardingCard(
                            onStartGuidedQuest: onStartGuidedQuest,
                            onCreate: onCreate,
                            onDefer: onDeferOnboarding
                        )
                    } else if pending.isEmpty && dailyGraves.isEmpty && !dailyFocusPresentation.isConfirmed {
                        EmptyDungeonState(onCreate: onCreate)
                    } else {
                        if recoveryPresentation == nil,
                           case let .recommended(questIDs) = dailyFocusPresentation {
                            DailyFocusRecommendationCard(
                                quests: quests(for: questIDs),
                                onEdit: {
                                    onEditDailyFocus(questIDs, .confirmation)
                                },
                                onConfirm: {
                                    onConfirmDailyFocus(questIDs)
                                }
                            )
                        }
                        QuestListSections(
                            heroAppearance: heroAppearance,
                            allQuests: allQuests,
                            pending: pending,
                            dailyGraves: dailyGraves,
                            newlyMissedQuestIDs: newlyMissedQuestIDs,
                            escalatedQuestIDs: escalatedQuestIDs,
                            guidedCompletionQuestID: onboardingPresentation.guidedCompletionQuestID,
                            dailyFocusQuestIDs: dailyFocusPresentation.selectedQuestIDs,
                            completedDailyFocusQuestIDs: dailyFocusPresentation.completedQuestIDs,
                            onEditDailyFocus: {
                                onEditDailyFocus(
                                    dailyFocusPresentation.selectedQuestIDs ?? [],
                                    .revision
                                )
                            },
                            now: now,
                            onComplete: onComplete,
                            onDelete: onDelete,
                            onOpenDetail: onOpenDetail
                        )
                        .animation(.default, value: pending.map(\.id))
                        .animation(.default, value: dailyGraves.map(\.id))
                    }
                    RoutineSection(
                        routines: visibleRoutines,
                        hasRoutineRules: hasRoutineRules,
                        onCreate: onCreateRoutine,
                        onManage: onManageRoutines,
                        onComplete: onCompleteRoutine
                    )
                    .animation(.default, value: visibleRoutines.map(\.id))
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            // Pinned rather than placed in the scrolled content, unlike `StoreFailureBanner`, which
            // renders at launch before there is anywhere to scroll. This one appears in response to
            // an action the user can take anywhere on the board, so inside the `LazyVStack` it would
            // land above the viewport and the rejected write would look like it worked.
            .safeAreaInset(edge: .bottom) {
                if lastCommitFailed {
                    CommitFailureBanner()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        .sheet(item: $presentedSheet, onDismiss: onSheetDismissed) { sheet in
            switch sheet {
            case .appearance:
                HeroAppearanceSheet(gender: heroGenderBinding, hairColor: heroHairColorBinding)
            case .hallOfFame:
                HallOfFameSheet(quests: allQuests, now: now)
            case .about:
                if let tipJarStore {
                    AboutSheet(store: tipJarStore)
                }
            case .reengagement:
                ReengagementReminderSettingsSheet(
                    settings: reengagementSettings,
                    hasCreatedQuest: hasCreatedQuest,
                    notificationAuthorization: notificationAuthorization,
                    onSave: onSaveReengagementSettings,
                    onOpenNotificationSettings: onOpenNotificationSettings
                )
            }
        }
    }

    private var heroAppearance: HeroAppearance {
        HeroAppearance(genderRawValue: heroGenderRawValue, hairColorRawValue: heroHairColorRawValue)
    }

    private var heroGenderBinding: Binding<HeroGender> {
        Binding(
            get: { heroAppearance.gender },
            set: { heroGenderRawValue = $0.rawValue }
        )
    }

    private var heroHairColorBinding: Binding<HeroHairColor> {
        Binding(
            get: { heroAppearance.hairColor },
            set: { heroHairColorRawValue = $0.rawValue }
        )
    }

    private func quests(for questIDs: [UUID]) -> [Quest] {
        let questsByID = Dictionary(uniqueKeysWithValues: allQuests.map { ($0.id, $0) })
        return questIDs.compactMap { questsByID[$0] }
    }

    private func recoveryQuest(
        for presentation: RecoveryCardPresentation
    ) -> Quest? {
        guard case let .singleQuest(questID) = presentation else { return nil }
        return allQuests.first { $0.id == questID }
    }
}

private struct TipJarStoreEnvironmentKey: EnvironmentKey {
    static let defaultValue: TipJarStore? = nil
}

extension EnvironmentValues {
    var tipJarStore: TipJarStore? {
        get { self[TipJarStoreEnvironmentKey.self] }
        set { self[TipJarStoreEnvironmentKey.self] = newValue }
    }
}

enum HomeDungeonSheet: String, Identifiable {
    case appearance
    case hallOfFame
    case about
    case reengagement

    var id: String { rawValue }
}

private struct DailyFocusRecommendationCard: View {
    let quests: [Quest]
    let onEdit: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.focusSectionTitle)
                .font(.headline.weight(.black))
                .foregroundStyle(DungeonPalette.ink)
            Text(AppStrings.focusRecommendationBody)
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(quests) { quest in
                    Text(verbatim: "• \(quest.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DungeonPalette.ink)
                        .lineLimit(2)
                }
            }
            HStack(spacing: 12) {
                Button(AppStrings.focusActionEdit, action: onEdit)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("focusPlanEditButton")
                Button(AppStrings.focusActionConfirm, action: onConfirm)
                    .buttonStyle(.pixel)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("focusPlanConfirmButton")
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.hero.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }
}

private extension DailyFocusPresentationState {
    var isConfirmed: Bool {
        guard case .confirmed = self else { return false }
        return true
    }

    var selectedQuestIDs: [UUID]? {
        guard case let .confirmed(selectedQuestIDs, _) = self else { return nil }
        return selectedQuestIDs
    }

    var completedQuestIDs: Set<UUID> {
        guard case let .confirmed(_, completedQuestIDs) = self else { return [] }
        return completedQuestIDs
    }
}

private struct GuidedOnboardingCard: View {
    let onStartGuidedQuest: () -> Void
    let onCreate: () -> Void
    let onDefer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.dungeonFirstWinTitle)
                .font(.headline.weight(.black))
                .foregroundStyle(DungeonPalette.ink)
            Text(AppStrings.dungeonFirstWinBody)
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            Button(AppStrings.dungeonFirstWinStart, action: onStartGuidedQuest)
                .buttonStyle(.pixel)
                .frame(maxWidth: .infinity, minHeight: 44)
            HStack(spacing: 12) {
                Button(AppStrings.dungeonFirstWinCreateOwn, action: onCreate)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button(AppStrings.dungeonFirstWinLater, action: onDefer)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DungeonPalette.ink)
        }
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.hero.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }
}

private extension OnboardingFlowPresentation {
    var guidedCompletionQuestID: UUID? {
        guard case let .guidedCompletion(questID) = self else { return nil }
        return questID
    }
}

private struct DungeonBackground: View {
    var body: some View {
        // Flat dungeon fill — DESIGN.md: "Do not add decorative glow blobs or gradients as filler."
        DungeonPalette.dungeon
            .ignoresSafeArea()
    }
}

private struct BoardHUD: View {
    let state: HeroState
    let isMourning: Bool
    let heroAppearance: HeroAppearance
    let onCreate: () -> Void
    let onEditAppearance: () -> Void
    let onOpenAbout: () -> Void
    let onOpenHallOfFame: () -> Void
    let onOpenReengagementSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: Brand.displayName)
                    .font(.title3.weight(.black).monospaced())
                    .foregroundStyle(DungeonPalette.ink)
                Spacer(minLength: 8)
                Button(action: onOpenReengagementSettings) {
                    Image(systemName: "bell")
                        .font(.headline.weight(.black))
                        .frame(width: 36, height: 36)
                        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
                        .overlay(
                            RoundedRectangle(cornerRadius: PixelStyle.corner)
                                .stroke(DungeonPalette.ink.opacity(0.25), lineWidth: PixelStyle.border)
                        )
                        .foregroundStyle(DungeonPalette.ink)
                }
                .accessibilityLabel(AppStrings.reengagementSettingsButtonAccessibility)
                .accessibilityIdentifier("reengagementReminderSettingsButton")
                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.black))
                        .frame(width: 36, height: 36)
                        // Chunky square pixel button rather than a soft circle.
                        .background(DungeonPalette.hero, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
                        .overlay(
                            RoundedRectangle(cornerRadius: PixelStyle.corner)
                                .stroke(DungeonPalette.ink.opacity(0.25), lineWidth: PixelStyle.border)
                        )
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(AppStrings.resolve(AppStrings.questActionAdd, locale: .current))
                .accessibilityIdentifier("questAddButton")
            }
            HeroHeader(
                state: state,
                isMourning: isMourning,
                appearance: heroAppearance,
                onEditAppearance: onEditAppearance,
                onOpenAbout: onOpenAbout,
                onOpenHallOfFame: onOpenHallOfFame
            )
        }
        .padding(14)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.ink.opacity(0.18), lineWidth: 2)  // chunky pixel border
        )
    }
}

private struct EmptyDungeonState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            DungeonArtworkView(artwork: .battleFlag, size: 34)
            Text(AppStrings.dungeonEmptyTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(DungeonPalette.ink)
                .accessibilityIdentifier("dungeonEmptyTitle")
            Text(AppStrings.dungeonEmptyBody)
                .font(.caption)
                .foregroundStyle(DungeonPalette.ink.opacity(0.7))
            Button(action: onCreate) {
                Label(AppStrings.questActionAdd, systemImage: "plus")
            }
            .buttonStyle(.pixel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
    }
}

/// Shown while the app is running on an in-memory fallback because the on-disk store would not open.
/// Informational, not a control — there is no action the user can take from here beyond relaunching,
/// so it is deliberately not a `Button` (which would replace the composed label for VoiceOver).
private struct StoreFailureBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(AppStrings.storeFailureBannerTitle)
            } icon: {
                DungeonArtworkView(artwork: .notificationsDisabled, size: 16)
            }
            .font(.caption.weight(.black))
            Text(AppStrings.storeFailureBannerBody)
                .font(.caption2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DungeonPalette.danger, in: RoundedRectangle(cornerRadius: 2))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("storeFailureBanner")
    }
}

/// Shown after the store refused a write and before any later write succeeded.
/// Informational for the same reason `StoreFailureBanner` is: the only recovery is to repeat the
/// action, which the user does on the board itself rather than from here.
private struct CommitFailureBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(AppStrings.commitFailureBannerTitle)
            } icon: {
                DungeonArtworkView(artwork: .notificationsDisabled, size: 16)
            }
            .font(.caption.weight(.black))
            Text(AppStrings.commitFailureBannerBody)
                .font(.caption2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DungeonPalette.danger, in: RoundedRectangle(cornerRadius: 2))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("commitFailureBanner")
    }
}

private struct NotificationPermissionBanner: View {
    let action: QuestNotificationPermissionAction
    let onAction: () -> Void

    var body: some View {
        Button(action: onAction) {
            Label {
                Text(bodyResource)
            } icon: {
                DungeonArtworkView(artwork: .notificationsDisabled, size: 16)
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(DungeonPalette.danger, in: RoundedRectangle(cornerRadius: 2))
        }
    }

    private var bodyResource: LocalizedStringResource {
        switch action {
        case .requestAuthorization:
            AppStrings.notificationPermissionRequestBody
        case .openSettings:
            AppStrings.notificationPermissionBannerBody
        }
    }
}
