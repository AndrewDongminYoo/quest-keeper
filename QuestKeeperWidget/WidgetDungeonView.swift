import AppIntents
import SwiftUI
import WidgetKit

struct WidgetDungeonView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuestKeeperWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        // Token background so the widget tracks light/dark like the app, instead of forcing black.
        .containerBackground(DungeonPalette.dungeon, for: .widget)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            statusLine

            if let mob = entry.state.activeMobs.first {
                MobBadge(mob: mob, compact: true)
            } else {
                emptyState
            }

            Spacer(minLength: 0)
            footer(fontSize: 9, iconSize: 12)
        }
        .padding(12)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            mediumHeader

            VStack(alignment: .leading, spacing: 4) {
                let mobs = Array(entry.state.activeMobs.prefix(3))
                let usesDenseRows = mobs.count == 3
                if mobs.isEmpty {
                    emptyState
                } else {
                    ForEach(mobs) { mob in
                        MobBadge(mob: mob, compact: false, dense: usesDenseRows)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            HStack(spacing: 8) {
                Text(mediumSummary)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
                footer(fontSize: 11, iconSize: 13)
            }
        }
        .padding(12)
    }

    private var mediumHeader: some View {
        HStack(spacing: 8) {
            Text(verbatim: Brand.displayName)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                StatPill(
                    label: WidgetStrings.resolve(WidgetStrings.statBattleLabel, locale: .current),
                    value: "\(entry.state.activeMobs.count)",
                    tint: DungeonPalette.guide
                )
                StatPill(
                    label: WidgetStrings.resolve(WidgetStrings.statVictoryLabel, locale: .current),
                    value: "\(entry.state.totalVictories)",
                    tint: DungeonPalette.victory
                )

                if !entry.state.dailyGraves.isEmpty {
                    StatPill(
                        label: WidgetStrings.resolve(WidgetStrings.statGraveLabel, locale: .current),
                        value: "\(entry.state.dailyGraves.count)",
                        tint: DungeonPalette.grave
                    )
                }
            }
        }
    }

    private var mediumSummary: String {
        if entry.state.isStale {
            return WidgetStrings.resolve(WidgetStrings.statusStaleReminder, locale: .current)
        }
        if entry.state.activeMobs.isEmpty {
            return WidgetStrings.resolve(WidgetStrings.statusDungeonQuiet, locale: .current)
        }
        if entry.state.activeMobs.count == 1 {
            return WidgetStrings.resolve(WidgetStrings.statusTopPriorityQuest, locale: .current)
        }
        return WidgetStrings.resolve(
            WidgetStrings.statusTodayQuestCount(entry.state.activeMobs.count),
            locale: .current
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: Brand.shortName)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 6) {
                StatPill(
                    label: WidgetStrings.resolve(WidgetStrings.statVictoryLabel, locale: .current),
                    value: "\(entry.state.totalVictories)",
                    tint: DungeonPalette.victory
                )

                if !entry.state.dailyGraves.isEmpty {
                    StatPill(
                        label: WidgetStrings.resolve(WidgetStrings.statGraveLabel, locale: .current),
                        value: "\(entry.state.dailyGraves.count)",
                        tint: DungeonPalette.grave
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if entry.state.isStale {
            StatusText(WidgetStrings.resolve(WidgetStrings.statusStaleReminder, locale: .current), tone: .muted)
        } else if entry.state.activeMobs.isEmpty {
            StatusText(WidgetStrings.resolve(WidgetStrings.statusDungeonQuiet, locale: .current), tone: .muted)
        } else if let mob = entry.state.activeMobs.first {
            StatusText(deadlineText(for: mob), tone: .color(urgencyTint(for: mob)))
                .privacySensitive()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.state.isStale ? WidgetStrings.emptyStaleTitle : WidgetStrings.emptyNoActiveTitle)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink.opacity(0.84))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(entry.state.isStale ? WidgetStrings.emptyStaleBody : WidgetStrings.emptyNoActiveBody)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink.opacity(0.62))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
        .overlay {
            RoundedRectangle(cornerRadius: PixelStyle.corner)
                .stroke(DungeonPalette.ink.opacity(0.14), lineWidth: 1)
        }
    }

    private func footer(fontSize: CGFloat, iconSize: CGFloat) -> some View {
        HStack(spacing: 6) {
            WidgetArtworkView(
                artwork: entry.state.isStale ? .staleWarning : .protectionShield,
                size: iconSize
            )

            Text(entry.state.generatedAt, style: .time)
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func deadlineText(for mob: WidgetMobState) -> String {
        if mob.deadline <= entry.state.date {
            return WidgetStrings.resolve(WidgetStrings.deadlineOverdue, locale: .current)
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let interval = formatter.localizedString(for: mob.deadline, relativeTo: entry.state.date)
        return WidgetStrings.resolve(WidgetStrings.deadlineRemaining(interval), locale: .current)
    }

    /// Urgency tint from the widget's derived `urgencyLevel`, aligned with the app's accent ramp.
    private func urgencyTint(for mob: WidgetMobState) -> Color {
        switch mob.urgencyLevel {
        case 3...: DungeonPalette.danger
        case 2: DungeonPalette.torch
        default: DungeonPalette.ink.opacity(0.7)
        }
    }
}

private struct MobBadge: View {
    let mob: WidgetMobState
    let compact: Bool
    var dense = false

    var body: some View {
        let monster = MonsterArtworkSelection.monster(forMobLevel: mob.mobLevel, questID: mob.id)

        // `systemSmall` shows the quest, not the bestiary: at that width the sprite and its gap
        // were spending ~30pt of a ~131pt row on flavour while the title got three characters a
        // line. The monster still leads every row in `systemMedium` and in the app.
        HStack(spacing: compact ? 5 : 8) {
            if !compact {
                WidgetArtworkView(
                    artwork: .monster(monster),
                    size: dense ? 18 : 22
                )
                .frame(
                    width: dense ? 20 : 24,
                    height: dense ? 20 : 24
                )
                .accessibilityLabel(WidgetStrings.resolve(
                    WidgetStrings.a11yMonsterLevel(monster.localizedName(), mob.mobLevel),
                    locale: .current
                ))
            }

            VStack(alignment: .leading, spacing: compact ? 2 : dense ? 0 : 1) {
                Text(mob.title)
                    .privacySensitive()
                    .font(.system(size: compact ? 12 : dense ? 10 : 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DungeonPalette.ink)
                    .lineLimit(compact ? 2 : 1)
                    .minimumScaleFactor(0.74)

                // `systemSmall` omits this row: its status line already shows the same deadline,
                // tinted by urgency, one line above. Drawing it twice cost the title its second
                // line and left the row itself unreadable — rendered in English it collapsed to
                // "- -" while the title showed "Re…". `systemMedium` has no per-mob status line,
                // so there this is the only place the time appears and it stays.
                if !compact {
                    HStack(spacing: 6) {
                        Text(WidgetStrings.mobDeadlineLabel)
                            .foregroundStyle(DungeonPalette.ink.opacity(0.56))

                        Text(mob.deadline, style: .timer)
                            .privacySensitive()
                            .foregroundStyle(DungeonPalette.ink.opacity(0.9))
                    }
                    .font(.system(size: dense ? 8 : 9, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }
            }

            Spacer(minLength: 0)

            // One-tap completion — runs CompleteQuestIntent in the widget process (spec 009).
            Button(intent: CompleteQuestIntent(questID: mob.id)) {
                if compact {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            DungeonPalette.hero,
                            in: RoundedRectangle(cornerRadius: PixelStyle.corner)
                        )
                } else {
                    Label {
                        Text(WidgetStrings.questActionComplete)
                    } icon: {
                        Image(systemName: "checkmark")
                            .font(.system(size: dense ? 8 : 10, weight: .black))
                    }
                    .font(.system(size: dense ? 8 : 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, dense ? 5 : 7)
                    .frame(minHeight: dense ? 22 : 26)
                    .background(
                        DungeonPalette.hero,
                        in: RoundedRectangle(cornerRadius: PixelStyle.corner)
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WidgetStrings.resolve(WidgetStrings.questActionComplete, locale: .current))
        }
        .padding(.vertical, compact ? 7 : dense ? 0 : 2)
        .padding(.horizontal, compact ? 6 : 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
        .overlay {
            RoundedRectangle(cornerRadius: PixelStyle.corner)
                .stroke(DungeonPalette.ink.opacity(0.16), lineWidth: 1)
        }
    }
}

/// Monsters carry their `MonsterKind` rather than re-listing the sprites: this enum used to name all
/// nine again and `preconditionFailure` when a name did not map, which made adding a `MonsterKind`
/// case a widget-process crash — "Unable to Load" on the Home Screen, with no user recovery. Reading
/// `MonsterKind.assetName` deletes the second list, so there is nothing left to fall out of sync.
private enum WidgetArtwork {
    case monster(MonsterKind)
    case staleWarning
    case protectionShield

    var assetName: String {
        switch self {
        case .monster(let kind): kind.assetName
        case .staleWarning: "icon-stale-warning"
        case .protectionShield: "icon-protection-shield"
        }
    }

    var contentScale: CGFloat {
        switch self {
        case .staleWarning, .protectionShield: 1.5
        case .monster: 1
        }
    }
}

private struct WidgetArtworkView: View {
    let artwork: WidgetArtwork
    let size: CGFloat

    var body: some View {
        Image(decorative: artwork.assetName)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(artwork.contentScale)
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
            Text(value)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.vertical, 3)
        .padding(.horizontal, 7)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: PixelStyle.corner))
    }
}

private struct StatusText: View {
    enum Tone {
        case muted
        case color(Color)
    }

    let text: String
    let tone: Tone

    init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(foregroundColor)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }

    private var foregroundColor: Color {
        switch tone {
        case .muted:
            DungeonPalette.ink.opacity(0.7)
        case let .color(color):
            color
        }
    }
}
