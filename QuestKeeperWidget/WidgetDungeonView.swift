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
            footer
        }
        .padding(12)
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                header
                statusLine
                gravePanel
                Spacer(minLength: 0)
                footer
            }
            .frame(width: 96, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                let mobs = Array(entry.state.activeMobs.prefix(3))
                if mobs.isEmpty {
                    emptyState
                } else {
                    ForEach(mobs) { mob in
                        MobBadge(mob: mob, compact: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(12)
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

    @ViewBuilder
    private var gravePanel: some View {
        if let grave = entry.state.dailyGraves.first {
            VStack(alignment: .leading, spacing: 4) {
                Text("오늘의 묘비")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DungeonPalette.ink.opacity(0.72))
                    .lineLimit(1)

                Text(grave.title)
                    .privacySensitive()
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DungeonPalette.ink.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
            .overlay {
                RoundedRectangle(cornerRadius: PixelStyle.corner)
                    .stroke(DungeonPalette.ink.opacity(0.14), lineWidth: 1)
            }
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

    private var footer: some View {
        HStack(spacing: 6) {
            WidgetArtworkView(
                artwork: entry.state.isStale ? .staleWarning : .protectionShield,
                size: 12
            )

            Text(entry.state.generatedAt, style: .time)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
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

    var body: some View {
        HStack(spacing: 8) {
            // Pixel monster — same sprite + tier tint the app renders (shared PixelSprite).
            PixelSprite(
                rows: DungeonSprites.monster(level: mob.mobLevel),
                palette: ["#": MobVisual.tint(level: mob.mobLevel), "o": DungeonPalette.stone]
            )
            .frame(width: compact ? 28 : 24, height: compact ? 28 : 24)
            .accessibilityLabel("몹 레벨 \(mob.mobLevel)")

            VStack(alignment: .leading, spacing: 2) {
                Text(mob.title)
                    .privacySensitive()
                    .font(.system(size: compact ? 12 : 11, weight: .bold, design: .monospaced))
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
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            // One-tap completion — runs CompleteQuestIntent in the widget process (spec 009).
            Button(intent: CompleteQuestIntent(questID: mob.id)) {
                WidgetArtworkView(artwork: .complete, size: compact ? 13 : 12)
                    .frame(width: compact ? 28 : 24, height: compact ? 28 : 24)
                    .background(
                        DungeonPalette.hero,
                        in: RoundedRectangle(cornerRadius: PixelStyle.corner)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("완료")
        }
        .padding(.vertical, compact ? 7 : 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
        .overlay {
            RoundedRectangle(cornerRadius: PixelStyle.corner)
                .stroke(DungeonPalette.ink.opacity(0.16), lineWidth: 1)
        }
    }
}

private enum WidgetArtwork: String {
    case complete = "icon-complete"
    case staleWarning = "icon-stale-warning"
    case protectionShield = "icon-protection-shield"
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
            .scaleEffect(1.5)
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
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
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
