import SwiftUI
import WidgetKit

struct WidgetDungeonView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuestKeeperWidgetEntry

    var body: some View {
        ZStack {
            DungeonBackdrop()

            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .containerBackground(.black, for: .widget)
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
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 6) {
                StatPill(label: "승리", value: "\(entry.state.totalVictories)", tint: .yellow)

                if !entry.state.dailyGraves.isEmpty {
                    StatPill(label: "묘비", value: "\(entry.state.dailyGraves.count)", tint: .red)
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
            StatusText(deadlineText(for: mob), tone: .color(urgencyTone(for: mob)))
        }
    }

    @ViewBuilder
    private var gravePanel: some View {
        if let grave = entry.state.dailyGraves.first {
            VStack(alignment: .leading, spacing: 4) {
                Text("오늘의 묘비")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)

                Text(grave.title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.state.isStale ? "던전 정보가 오래됐습니다" : "활성 퀘스트가 없습니다")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(entry.state.isStale ? "앱을 열어 다시 동기화하세요" : "새 퀘스트를 추가해 던전을 채우세요")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.state.isStale ? "exclamationmark.triangle.fill" : "shield.lefthalf.filled")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(entry.state.isStale ? .orange : .green)

            Text(entry.state.generatedAt, style: .time)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
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

    private func urgencyTone(for mob: WidgetMobState) -> Color {
        switch mob.urgencyLevel {
        case 3...:
            return .red.opacity(0.92)
        case 2:
            return .orange.opacity(0.92)
        default:
            return .green.opacity(0.88)
        }
    }
}

private struct MobBadge: View {
    let mob: WidgetMobState
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: compact ? 28 : 24, height: compact ? 28 : 24)

                Text("\(mob.mobLevel)")
                    .font(.system(size: compact ? 13 : 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(mob.title)
                    .font(.system(size: compact ? 12 : 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(compact ? 2 : 1)
                    .minimumScaleFactor(0.74)

                HStack(spacing: 6) {
                    Text("기한")
                        .foregroundStyle(.white.opacity(0.56))

                    Text(mob.deadline, style: .timer)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 7 : 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var levelColor: Color {
        if mob.mobLevel >= 9 { return .red }
        if mob.mobLevel >= 5 { return .orange }
        return .green
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
        .background(tint.opacity(0.14), in: Capsule())
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
            return .white.opacity(0.7)
        case let .color(color):
            return color
        }
    }
}

private struct DungeonBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.07, blue: 0.12),
                Color(red: 0.15, green: 0.15, blue: 0.20),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.24))
                .frame(height: 18)
        }
    }
}
