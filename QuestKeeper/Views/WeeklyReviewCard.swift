import SwiftUI

/// The account of the week that just ended, with one action that starts this one.
/// See `docs/specs/026-weekly-review.md`; the figures come from `WeeklyReviewState`.
struct WeeklyReviewCard: View {
    let review: WeeklyReview
    let onPlan: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.weeklyReviewTitle)
                    .font(.headline.weight(.black))
                    .foregroundStyle(DungeonPalette.ink)
                Text(AppStrings.weeklyReviewRange(formatted(review.weekStart), formatted(lastDay)))
                    .font(.caption)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.7))
            }

            // 성취를 먼저, 증감은 그 아래 한 문장으로. 조용했던 주에는 수치 열 자체를 감춘다.
            if review.hasVictories {
                HStack(alignment: .top, spacing: 20) {
                    stat(AppStrings.weeklyReviewStatVictories, review.victories)
                    stat(AppStrings.weeklyReviewStatActiveDays, review.activeDays)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(AppStrings.weeklyReviewStatsAccessibility(
                    victories: review.victories,
                    activeDays: review.activeDays
                )))
                Text(changeResource)
                    .font(.caption)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(review.hasVictories
                ? AppStrings.weeklyReviewBodyWithVictories
                : AppStrings.weeklyReviewBodyQuiet)
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(AppStrings.weeklyReviewActionDismiss, action: onDismiss)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("weeklyReviewDismissButton")
                Button(AppStrings.weeklyReviewActionPlan, action: onPlan)
                    .buttonStyle(.pixel)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("weeklyReviewPlanButton")
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.hero.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weeklyReviewCard")
    }

    /// `weekEnd` is the next week's first instant, so the last day the card names is one second back.
    private var lastDay: Date { review.weekEnd.addingTimeInterval(-1) }

    private var changeResource: LocalizedStringResource {
        if review.change > 0 { return AppStrings.weeklyReviewChangeUp(review.change) }
        if review.change < 0 { return AppStrings.weeklyReviewChangeDown(-review.change) }
        return AppStrings.weeklyReviewChangeSame
    }

    /// The calendar is named rather than inherited: `ContentView` derives the week with
    /// `Calendar.current`, and a label formatted through a different one would name a different
    /// week than the figures above it describe.
    private func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: .current, timeZone: .current)
        )
    }

    private func stat(_ label: LocalizedStringResource, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title2.weight(.black).monospacedDigit())
                .foregroundStyle(DungeonPalette.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("A busy week") {
    WeeklyReviewCard(
        review: WeeklyReview(
            weekStart: Date(timeIntervalSinceReferenceDate: 800_000_000),
            weekEnd: Date(timeIntervalSinceReferenceDate: 800_604_800),
            victories: 7,
            activeDays: 4,
            change: 3
        ),
        onPlan: {},
        onDismiss: {}
    )
    .padding()
    .background(DungeonPalette.dungeon)
}

#Preview("A quiet week") {
    WeeklyReviewCard(
        review: WeeklyReview(
            weekStart: Date(timeIntervalSinceReferenceDate: 800_000_000),
            weekEnd: Date(timeIntervalSinceReferenceDate: 800_604_800),
            victories: 0,
            activeDays: 0,
            change: 0
        ),
        onPlan: {},
        onDismiss: {}
    )
    .padding()
    .background(DungeonPalette.dungeon)
}
