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
            Text("QUEST KEEPER")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                StatPill(label: "전투", value: "\(entry.state.activeMobs.count)", tint: DungeonPalette.guide)
                StatPill(label: "승리", value: "\(entry.state.totalVictories)", tint: DungeonPalette.victory)

                if !entry.state.dailyGraves.isEmpty {
                    StatPill(label: "묘비", value: "\(entry.state.dailyGraves.count)", tint: DungeonPalette.grave)
                }
            }
        }
    }

    private var mediumSummary: String {
        if entry.state.isStale {
            return "앱을 열면 갱신됩니다"
        }
        if entry.state.activeMobs.isEmpty {
            return "던전이 조용합니다"
        }
        if entry.state.activeMobs.count == 1 {
            return "오늘의 최우선 퀘스트"
        }
        return "오늘의 퀘스트 \(entry.state.activeMobs.count)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("QUEST")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 6) {
                StatPill(label: "승리", value: "\(entry.state.totalVictories)", tint: DungeonPalette.victory)

                if !entry.state.dailyGraves.isEmpty {
                    StatPill(label: "묘비", value: "\(entry.state.dailyGraves.count)", tint: DungeonPalette.grave)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if entry.state.isStale {
            StatusText("앱을 열면 갱신됩니다", tone: .muted)
        } else if entry.state.activeMobs.isEmpty {
            StatusText("던전이 조용합니다", tone: .muted)
        } else if let mob = entry.state.activeMobs.first {
            StatusText(deadlineText(for: mob), tone: .color(urgencyTint(for: mob)))
                .privacySensitive()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.state.isStale ? "던전 정보가 오래됐습니다" : "활성 퀘스트가 없습니다")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DungeonPalette.ink.opacity(0.84))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(entry.state.isStale ? "앱을 열어 다시 동기화하세요" : "새 퀘스트를 추가해 던전을 채우세요")
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
            return "기한 초과"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "\(formatter.localizedString(for: mob.deadline, relativeTo: entry.state.date)) 남음"
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

        HStack(spacing: 8) {
            WidgetArtworkView(
                artwork: .monster(level: mob.mobLevel, questID: mob.id),
                size: compact ? 28 : dense ? 18 : 22
            )
            .frame(
                width: compact ? 28 : dense ? 20 : 24,
                height: compact ? 28 : dense ? 20 : 24
            )
            .accessibilityLabel("\(monster.localizedName) 레벨 \(mob.mobLevel)")

            VStack(alignment: .leading, spacing: compact ? 2 : dense ? 0 : 1) {
                Text(mob.title)
                    .privacySensitive()
                    .font(.system(size: compact ? 12 : dense ? 10 : 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DungeonPalette.ink)
                    .lineLimit(compact ? 2 : 1)
                    .minimumScaleFactor(0.74)

                HStack(spacing: 6) {
                    Text("기한")
                        .foregroundStyle(DungeonPalette.ink.opacity(0.56))

                    Text(mob.deadline, style: .timer)
                        .privacySensitive()
                        .foregroundStyle(DungeonPalette.ink.opacity(0.9))
                }
                .font(.system(size: dense ? 8 : 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
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
                        Text("완료")
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
            .accessibilityLabel("완료")
        }
        .padding(.vertical, compact ? 7 : dense ? 0 : 2)
        .padding(.horizontal, compact ? 8 : 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
        .overlay {
            RoundedRectangle(cornerRadius: PixelStyle.corner)
                .stroke(DungeonPalette.ink.opacity(0.16), lineWidth: 1)
        }
    }
}

private enum WidgetArtwork: String {
    case slime = "sprite-slime"
    case bat = "sprite-bat"
    case mushroom = "sprite-mushroom"
    case skeleton = "sprite-skeleton"
    case orc = "sprite-orc"
    case mimic = "sprite-mimic"
    case dragon = "sprite-dragon"
    case golem = "sprite-golem"
    case lich = "sprite-lich"
    case staleWarning = "icon-stale-warning"
    case protectionShield = "icon-protection-shield"

    var contentScale: CGFloat {
        switch self {
        case .staleWarning, .protectionShield:
            1.5
        case .slime, .bat, .mushroom, .skeleton, .orc, .mimic, .dragon, .golem, .lich:
            1
        }
    }

    static func monster(level: Int, questID: UUID) -> WidgetArtwork {
        let assetName = MonsterArtworkSelection.monster(forMobLevel: level, questID: questID).assetName
        guard let artwork = WidgetArtwork(rawValue: assetName) else {
            preconditionFailure("Missing widget monster artwork for \(assetName)")
        }
        return artwork
    }
}

private struct WidgetArtworkView: View {
    let artwork: WidgetArtwork
    let size: CGFloat

    var body: some View {
        Image(decorative: artwork.rawValue)
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
