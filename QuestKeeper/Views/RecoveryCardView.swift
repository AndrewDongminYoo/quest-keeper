import SwiftUI

struct RecoveryCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingSelectionIssue = false

    let presentation: RecoveryCardPresentation
    let quest: Quest?
    let now: Date
    let onConfirmSingleQuest: (UUID) -> Bool
    let onChooseToday: () -> Void
    let onCreateQuest: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.recoveryCardTitle)
                .font(.headline.weight(.black))
                .foregroundStyle(DungeonPalette.ink)
            Text(AppStrings.recoveryCardBody)
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(AppStrings.resolve(AppStrings.recoveryCardBodyAccessibility, locale: .current))

            if case .singleQuest = presentation, let quest {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DungeonPalette.ink)
                    Text(DungeonPresentation.countdownText(
                        deadline: quest.deadline,
                        now: now
                    ))
                    .font(.caption)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                }
            }

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(PixelButtonStyle(
                    fill: DungeonPalette.hero,
                    foreground: colorScheme == .dark ? DungeonPalette.dungeon : .white
                ))
                .frame(maxWidth: .infinity, minHeight: 44)
            Button(AppStrings.recoveryCardDismiss, action: onDismiss)
                .frame(maxWidth: .infinity, minHeight: 44)
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
        .alert(AppStrings.selectionReissueAlertTitle, isPresented: $showingSelectionIssue) {
            Button(AppStrings.selectionReissueAlertConfirmAction, role: .cancel) { }
        } message: {
            Text(AppStrings.selectionReissueAlertMessage)
        }
    }

    private var primaryTitle: LocalizedStringResource {
        switch presentation {
        case .singleQuest:
            AppStrings.recoveryCardPrimarySingleQuest
        case .chooseToday:
            AppStrings.recoveryCardPrimaryChooseToday
        case .createQuest:
            AppStrings.recoveryCardPrimaryCreateQuest
        }
    }

    private func primaryAction() {
        switch presentation {
        case .singleQuest(let questID):
            if !onConfirmSingleQuest(questID) {
                showingSelectionIssue = true
            }
        case .chooseToday:
            onChooseToday()
        case .createQuest:
            onCreateQuest()
        }
    }
}

#Preview("Single quest") {
    RecoveryCardView(
        presentation: .singleQuest(UUID()),
        quest: Quest(
            title: AppStrings.resolve(AppStrings.recoveryCardPreviewLongTitle, locale: .current),
            deadline: Date.now.addingTimeInterval(600),
            importance: .medium
        ),
        now: .now,
        onConfirmSingleQuest: { _ in true },
        onChooseToday: { },
        onCreateQuest: { },
        onDismiss: { }
    )
    .padding()
    .background(DungeonPalette.dungeon)
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Choose today") {
    RecoveryCardView(
        presentation: .chooseToday,
        quest: nil,
        now: .now,
        onConfirmSingleQuest: { _ in true },
        onChooseToday: { },
        onCreateQuest: { },
        onDismiss: { }
    )
    .padding()
    .background(DungeonPalette.dungeon)
}

#Preview("Create quest") {
    RecoveryCardView(
        presentation: .createQuest,
        quest: nil,
        now: .now,
        onConfirmSingleQuest: { _ in true },
        onChooseToday: { },
        onCreateQuest: { },
        onDismiss: { }
    )
    .padding()
    .background(DungeonPalette.dungeon)
}
