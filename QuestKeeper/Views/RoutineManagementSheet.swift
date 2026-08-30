import SwiftUI

struct RoutineManagementSheet: View {
    @Environment(\.dismiss) private var dismiss

    let routines: [RoutineRule]
    let onCreate: () -> Void
    let onEdit: (RoutineRule) -> Void
    let onDelete: (RoutineRule) -> Void

    var body: some View {
        NavigationStack {
            List {
                if routines.isEmpty {
                    Text(AppStrings.routineEmptyBody)
                        .foregroundStyle(DungeonPalette.ink.opacity(0.72))
                        .listRowBackground(DungeonPalette.stone)
                } else {
                    ForEach(routines) { routine in
                        HStack(spacing: 12) {
                            Button(action: { onEdit(routine) }) {
                                Text(routine.title)
                                    .foregroundStyle(DungeonPalette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("routineManage-\(routine.id.uuidString)")

                            Button(role: .destructive, action: { onDelete(routine) }) {
                                DungeonArtworkView(artwork: .delete, size: 18)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(AppStrings.resolve(AppStrings.questActionDelete, locale: .current))
                            .accessibilityIdentifier("routineDelete-\(routine.id.uuidString)")
                        }
                        .listRowBackground(DungeonPalette.stone)
                    }
                }
            }
            .navigationTitle(AppStrings.routineManagementNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(DungeonPalette.dungeon)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.commonActionClose) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.routineAddAction, action: onCreate)
                        .accessibilityIdentifier("routineManagementAddButton")
                }
            }
        }
    }
}
