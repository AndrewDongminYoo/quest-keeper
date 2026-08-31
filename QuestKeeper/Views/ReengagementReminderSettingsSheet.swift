import SwiftUI

struct ReengagementReminderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let hasCreatedQuest: Bool
    let notificationAuthorization: QuestNotificationAuthorization?
    let onSave: (ReengagementReminderSettings) -> Void
    let onOpenNotificationSettings: () -> Void

    @State private var settings: ReengagementReminderSettings

    init(
        settings: ReengagementReminderSettings,
        hasCreatedQuest: Bool,
        notificationAuthorization: QuestNotificationAuthorization?,
        onSave: @escaping (ReengagementReminderSettings) -> Void,
        onOpenNotificationSettings: @escaping () -> Void
    ) {
        self.hasCreatedQuest = hasCreatedQuest
        self.notificationAuthorization = notificationAuthorization
        self.onSave = onSave
        self.onOpenNotificationSettings = onOpenNotificationSettings
        _settings = State(initialValue: settings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(AppStrings.reengagementSettingsEnabled, isOn: $settings.isEnabled)
                        .disabled(!hasCreatedQuest)
                        .accessibilityIdentifier("reengagementReminderEnabledToggle")
                    if !hasCreatedQuest {
                        Text(AppStrings.reengagementSettingsFirstQuestRequired)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(AppStrings.reengagementSettingsScheduleSection) {
                    DatePicker(
                        AppStrings.reengagementSettingsTime,
                        selection: timeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    Picker(AppStrings.reengagementSettingsFrequency, selection: $settings.frequency) {
                        Text(AppStrings.reengagementSettingsFrequencyDaily)
                            .tag(ReengagementReminderFrequency.daily)
                        Text(AppStrings.reengagementSettingsFrequencyWeekdays)
                            .tag(ReengagementReminderFrequency.weekdays)
                    }
                }

                Section(AppStrings.reengagementSettingsQuietHoursSection) {
                    Toggle(AppStrings.reengagementSettingsQuietHoursEnabled, isOn: quietHoursEnabled)
                    if settings.quietHours != nil {
                        DatePicker(
                            AppStrings.reengagementSettingsQuietHoursStart,
                            selection: quietHoursStartBinding,
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            AppStrings.reengagementSettingsQuietHoursEnd,
                            selection: quietHoursEndBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section(AppStrings.reengagementSettingsPurposeSection) {
                    Picker(AppStrings.reengagementSettingsPurpose, selection: $settings.purpose) {
                        Text(AppStrings.reengagementSettingsPurposeFinishOneQuest)
                            .tag(ReengagementReminderPurpose.finishOneQuest)
                        Text(AppStrings.reengagementSettingsPurposeReviewPlan)
                            .tag(ReengagementReminderPurpose.reviewPlan)
                    }
                }

                if settings.isEnabled && !settings.isScheduleValid {
                    Section {
                        Text(AppStrings.reengagementSettingsQuietHoursConflict)
                            .foregroundStyle(.secondary)
                    }
                }

                permissionSection
            }
            .navigationTitle(AppStrings.reengagementSettingsNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.commonActionCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.questEditorSaveAction) {
                        onSave(settings)
                        dismiss()
                    }
                    .accessibilityIdentifier("reengagementReminderSaveButton")
                }
            }
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        switch notificationAuthorization {
        case .notDetermined:
            Section(AppStrings.reengagementSettingsPermissionSection) {
                Text(AppStrings.reengagementSettingsPermissionRequestExplanation)
                    .foregroundStyle(.secondary)
            }
        case .denied:
            Section(AppStrings.reengagementSettingsPermissionSection) {
                Text(AppStrings.reengagementSettingsPermissionDeniedExplanation)
                    .foregroundStyle(.secondary)
                Button(AppStrings.reengagementSettingsOpenSystemSettings, action: onOpenNotificationSettings)
            }
        case .allowed, .unavailable, nil:
            EmptyView()
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { date(for: settings.minuteOfDay) },
            set: { settings.minuteOfDay = minuteOfDay(for: $0) }
        )
    }

    private var quietHoursEnabled: Binding<Bool> {
        Binding(
            get: { settings.quietHours != nil },
            set: { isEnabled in
                settings.quietHours = isEnabled
                    ? settings.quietHours ?? ReengagementQuietHours(startMinute: 22 * 60, endMinute: 8 * 60)
                    : nil
            }
        )
    }

    private var quietHoursStartBinding: Binding<Date> {
        Binding(
            get: { date(for: settings.quietHours?.startMinute ?? 22 * 60) },
            set: { updateQuietHours(startMinute: minuteOfDay(for: $0)) }
        )
    }

    private var quietHoursEndBinding: Binding<Date> {
        Binding(
            get: { date(for: settings.quietHours?.endMinute ?? 8 * 60) },
            set: { updateQuietHours(endMinute: minuteOfDay(for: $0)) }
        )
    }

    private func updateQuietHours(startMinute: Int? = nil, endMinute: Int? = nil) {
        guard let quietHours = settings.quietHours else { return }
        settings.quietHours = ReengagementQuietHours(
            startMinute: startMinute ?? quietHours.startMinute,
            endMinute: endMinute ?? quietHours.endMinute
        )
    }

    private func date(for minuteOfDay: Int) -> Date {
        let minute = min(max(minuteOfDay, 0), ReengagementReminderSettings.minutesPerDay - 1)
        return Calendar.current.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
