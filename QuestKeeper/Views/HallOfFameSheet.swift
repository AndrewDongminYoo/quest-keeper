import SwiftUI

struct HallOfFameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let quests: [Quest]
    let now: Date

    private var victoryQuests: [Quest] {
        let questsByID = Dictionary(uniqueKeysWithValues: quests.map { ($0.id, $0) })
        return HallOfFameState
            .victoryQuestIDs(quests: quests.map(\.snapshot), now: now)
            .compactMap { questsByID[$0] }
    }

    var body: some View {
        NavigationStack {
            Group {
                if victoryQuests.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            DungeonArtworkView(artwork: .victoryTrophy, size: 38)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 4)
                            ForEach(victoryQuests) { quest in
                                Text(quest.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(DungeonPalette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(DungeonPalette.ink.opacity(0.18), lineWidth: 2)
                                    )
                                    .accessibilityIdentifier("hallOfFameQuest-\(quest.id.uuidString)")
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(AppStrings.hallOfFameNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .background(DungeonPalette.dungeon)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.commonActionClose) { dismiss() }
                        .accessibilityIdentifier("hallOfFameCloseButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            DungeonArtworkView(artwork: .victoryTrophy, size: 38)
            Text(AppStrings.hallOfFameEmptyBody)
                .font(.body)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("hallOfFameEmptyState")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

#Preview("Victories") {
    HallOfFameSheet(
        quests: [
            Quest(
                title: String(repeating: "A long Hall of Fame title ", count: 3),
                deadline: Date(timeIntervalSinceReferenceDate: 800_000_000),
                importance: .medium,
                completedAt: Date(timeIntervalSinceReferenceDate: 799_999_000)
            )
        ],
        now: Date(timeIntervalSinceReferenceDate: 800_000_000)
    )
}

#Preview("Empty") {
    HallOfFameSheet(quests: [], now: Date(timeIntervalSinceReferenceDate: 800_000_000))
}
