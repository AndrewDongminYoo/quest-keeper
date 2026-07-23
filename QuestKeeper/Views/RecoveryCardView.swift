import SwiftUI

struct RecoveryCardView: View {
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
            Text("다시 와서 반가워요")
                .font(.headline.weight(.black))
                .foregroundStyle(DungeonPalette.ink)
            Text("쉬었다 와도 괜찮아요. 오늘 할 일부터 가볍게 시작해볼까요?")
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

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
                .buttonStyle(.pixel)
                .frame(maxWidth: .infinity, minHeight: 44)
            Button("지금은 괜찮아요", action: onDismiss)
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
        .alert("선택을 다시 확인해주세요", isPresented: $showingSelectionIssue) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("퀘스트 상태가 바뀌어 지금 선택을 저장하지 않았습니다.")
        }
    }

    private var primaryTitle: String {
        switch presentation {
        case .singleQuest:
            "이 퀘스트로 다시 시작"
        case .chooseToday:
            "오늘 다시 고르기"
        case .createQuest:
            "작은 퀘스트 만들기"
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
            title: "천천히 다시 시작하는 아주 긴 회복 퀘스트 제목",
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
