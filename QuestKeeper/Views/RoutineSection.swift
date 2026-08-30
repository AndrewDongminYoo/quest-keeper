import SwiftUI

struct RoutineSection: View {
    let routines: [RoutineRule]
    let hasRoutineRules: Bool
    let onCreate: () -> Void
    let onManage: () -> Void
    let onComplete: (RoutineRule) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(AppStrings.routineSectionTitle)
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(DungeonPalette.ink.opacity(0.82))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("routineSectionTitle")
                Spacer(minLength: 8)
                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DungeonPalette.ink)
                .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(DungeonPalette.ink.opacity(0.18), lineWidth: 2)
                )
                .accessibilityLabel(AppStrings.resolve(AppStrings.routineAddAction, locale: .current))
                .accessibilityIdentifier("routineHomeAddButton")
            }

            if routines.isEmpty {
                Text(hasRoutineRules ? AppStrings.routineCompletedTodayBody : AppStrings.routineEmptyBody)
                    .font(.subheadline)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
            } else {
                VStack(spacing: 10) {
                    ForEach(routines) { routine in
                        RoutineRow(routine: routine) {
                            onComplete(routine)
                        }
                    }
                }
            }

            if hasRoutineRules {
                Button(AppStrings.routineManageAction, action: onManage)
                    .font(.caption.weight(.bold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("routineHomeManageButton")
            }
        }
    }
}

private struct RoutineRow: View {
    let routine: RoutineRule
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            DungeonArtworkView(artwork: .battleFlag, size: 24)
                .frame(width: 28, height: 28)
            Text(routine.title)
                .font(.body.weight(.bold))
                .foregroundStyle(DungeonPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onComplete) {
                DungeonArtworkView(artwork: .complete, size: 22)
                    .frame(width: 44, height: 44)
                    .background(DungeonPalette.hero, in: RoundedRectangle(cornerRadius: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                AppStrings.resolve(AppStrings.a11yRoutineComplete(routine.title), locale: .current)
            )
            .accessibilityIdentifier("routineComplete-\(routine.id.uuidString)")
        }
        .padding(12)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.ink.opacity(0.18), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }
}
