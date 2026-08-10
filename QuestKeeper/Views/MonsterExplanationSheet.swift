import SwiftUI

nonisolated struct MonsterExplanationTier: Equatable, Identifiable {
    let family: MonsterFamily
    let levels: ClosedRange<Int>
    let kinds: [MonsterKind]

    var id: Int { levels.lowerBound }
}

/// The tier table is read back out of the same mapping the row renderer uses, so a
/// GameBalance change cannot leave the explanation describing a rule that no longer holds.
nonisolated enum MonsterExplanation {
    static func tiers(maxMobLevel: Int) -> [MonsterExplanationTier] {
        var tiers: [MonsterExplanationTier] = []
        for level in 0...maxMobLevel {
            let family = MonsterArtworkSelection.family(forMobLevel: level)
            if let last = tiers.last, last.family == family {
                tiers[tiers.count - 1] = MonsterExplanationTier(
                    family: family,
                    levels: last.levels.lowerBound...level,
                    kinds: last.kinds
                )
            } else {
                tiers.append(MonsterExplanationTier(
                    family: family,
                    levels: level...level,
                    kinds: kinds(for: family)
                ))
            }
        }
        return tiers
    }

    /// Mirrors the variant lists in `MonsterArtworkSelection.monster(forMobLevel:questID:)`.
    static func kinds(for family: MonsterFamily) -> [MonsterKind] {
        switch family {
        case .low: [.slime, .bat, .mushroom]
        case .medium: [.skeleton, .orc, .mimic]
        case .high: [.dragon, .golem, .lich]
        }
    }
}

struct MonsterExplanationSheet: View {
    let quest: Quest
    let now: Date

    @Environment(\.dismiss) private var dismiss

    private var level: Int { quest.snapshot.mobLevel(at: now) }
    private var kind: MonsterKind {
        MonsterArtworkSelection.monster(forMobLevel: level, questID: quest.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        DungeonArtworkView(artwork: .monster(level: level, questID: quest.id), size: 56)
                        Text(verbatim: "\(importanceName)  ×  \(countdown)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DungeonPalette.ink)
                        Text(verbatim: "\(AppStrings.resolve(AppStrings.monsterExplanationImportanceCaption, locale: .current))  ·  \(AppStrings.resolve(AppStrings.monsterExplanationUrgencyCaption, locale: .current))")
                            .font(.caption)
                            .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                        Text(verbatim: "→  Lv \(level) · \(kind.localizedName())")
                            .font(.body.weight(.bold).monospacedDigit())
                            .foregroundStyle(DungeonPalette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .listRowBackground(DungeonPalette.stone)

                Section(AppStrings.monsterExplanationRulesTitle) {
                    ForEach(MonsterExplanation.tiers(maxMobLevel: GameBalance.maxMobLevel)) { tier in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "Lv \(tier.levels.lowerBound)-\(tier.levels.upperBound)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(DungeonPalette.ink.opacity(0.72))
                            Text(verbatim: tier.kinds.map { $0.localizedName() }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(DungeonPalette.ink)
                        }
                    }
                    Text(AppStrings.monsterExplanationRulesBody)
                        .font(.caption)
                        .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(DungeonPalette.stone)
            }
            .formStyle(.grouped)
            .navigationTitle(AppStrings.monsterExplanationNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(DungeonPalette.dungeon)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.monsterExplanationDoneAction) { dismiss() }
                        .accessibilityIdentifier("monsterExplanationDoneButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var importanceName: String {
        switch quest.importance {
        case .low: AppStrings.resolve(AppStrings.questEditorImportanceLow, locale: .current)
        case .medium: AppStrings.resolve(AppStrings.questEditorImportanceMedium, locale: .current)
        case .high: AppStrings.resolve(AppStrings.questEditorImportanceHigh, locale: .current)
        }
    }

    private var countdown: String {
        DungeonPresentation.countdownText(deadline: quest.deadline, now: now)
    }
}
