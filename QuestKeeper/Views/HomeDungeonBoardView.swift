import SwiftUI

struct HomeDungeonBoardView: View {
    let state: HeroState
    let isMourning: Bool
    let pending: [Quest]
    let dailyGraves: [Quest]
    let newlyMissedQuestIDs: Set<UUID>
    let now: Date
    let showsNotificationPermissionBanner: Bool
    let onCreate: () -> Void
    let onOpenNotificationSettings: () -> Void
    let onComplete: (Quest, Date) -> Void
    let onRetryTomorrow: (Quest) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            DungeonBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    BoardHUD(state: state, isMourning: isMourning, onCreate: onCreate)
                    if showsNotificationPermissionBanner {
                        NotificationPermissionBanner(onOpenSettings: onOpenNotificationSettings)
                    }
                    if pending.isEmpty && dailyGraves.isEmpty {
                        EmptyDungeonState(onCreate: onCreate)
                    } else {
                        QuestListSections(
                            pending: pending,
                            dailyGraves: dailyGraves,
                            newlyMissedQuestIDs: newlyMissedQuestIDs,
                            now: now,
                            onComplete: onComplete,
                            onRetryTomorrow: onRetryTomorrow,
                            onDelete: onDelete,
                            onEdit: onEdit
                        )
                        .animation(.default, value: pending.map(\.id))
                        .animation(.default, value: dailyGraves.map(\.id))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
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
    let onCreate: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HeroHeader(state: state, isMourning: isMourning)
            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(DungeonPalette.hero, in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("전투 추가")
        }
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DungeonPalette.ink.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct EmptyDungeonState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(DungeonPalette.victory)
            Text("오늘의 던전이 비었습니다")
                .font(.headline.weight(.bold))
                .foregroundStyle(DungeonPalette.ink)
            Text("작은 전투 하나를 추가해 시작하세요.")
                .font(.caption)
                .foregroundStyle(DungeonPalette.ink.opacity(0.7))
            Button(action: onCreate) {
                Label("전투 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(DungeonPalette.hero)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NotificationPermissionBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: onOpenSettings) {
            Label("마감 알림을 받으려면 설정에서 QuestKeeper 알림을 켜세요.", systemImage: "bell.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(DungeonPalette.danger, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
