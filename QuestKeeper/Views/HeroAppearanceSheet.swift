import SwiftUI

struct HeroAppearanceSheet: View {
    @Binding var gender: HeroGender
    @Binding var hairColor: HeroHairColor

    @Environment(\.dismiss) private var dismiss

    private var appearance: HeroAppearance {
        HeroAppearance(gender: gender, hairColor: hairColor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HeroSprite(isMourning: false, appearance: appearance, size: 112)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                .listRowBackground(DungeonPalette.stone)

                Section(AppStrings.heroAppearanceGenderSection) {
                    Picker(AppStrings.heroAppearanceGenderSection, selection: $gender) {
                        ForEach(HeroGender.allCases, id: \.self) { option in
                            Text(option.title()).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(DungeonPalette.stone)

                Section(AppStrings.heroAppearanceHairColorSection) {
                    Picker(AppStrings.heroAppearanceHairColorSection, selection: $hairColor) {
                        ForEach(HeroHairColor.allCases, id: \.self) { option in
                            Text(option.title()).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                .listRowBackground(DungeonPalette.stone)
            }
            .formStyle(.grouped)
            .navigationTitle(AppStrings.heroAppearanceNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(DungeonPalette.dungeon)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.heroAppearanceDoneAction) { dismiss() }
                        .accessibilityIdentifier("heroAppearanceDoneButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    HeroAppearanceSheet(gender: .constant(.female), hairColor: .constant(.red))
}
