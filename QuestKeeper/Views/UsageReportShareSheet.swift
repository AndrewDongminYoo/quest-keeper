import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct UsageReportShareSheet: View {
    let loader: UsageReportExportLoader
    let appVersion: String
    let buildNumber: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var state: UsageReportShareState = .loading

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard

                    reportContent
                }
                .padding(16)
            }
            .navigationTitle(AppStrings.usageReportNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .background(DungeonPalette.dungeon)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.usageReportDoneAction) { dismiss() }
                        .accessibilityIdentifier("usageReportDisclosureDoneButton")
                }
            }
            .task { loadReport() }
        }
        .presentationDetents([.medium, .large])
    }

    private var introCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(DungeonPalette.hero)
                .frame(width: 48, height: 48)
                .background(DungeonPalette.hero.opacity(0.14), in: RoundedRectangle(cornerRadius: PixelStyle.corner))
                .accessibilityHidden(true)

            Text(AppStrings.usageReportIntro)
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
        .overlay(
            RoundedRectangle(cornerRadius: PixelStyle.corner)
                .stroke(DungeonPalette.hero.opacity(0.55), lineWidth: PixelStyle.border)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("usageReportIntroCard")
    }

    @ViewBuilder
    private var reportContent: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)

        case .unavailable:
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                    .accessibilityHidden(true)
                Text(AppStrings.usageReportUnavailable)
                    .foregroundStyle(DungeonPalette.ink)
                    .accessibilityIdentifier("usageReportUnavailableMessage")
            }
            .usageReportCard(border: DungeonPalette.ink.opacity(0.18))

        case .encodingFailed:
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DungeonPalette.danger)
                    .accessibilityHidden(true)
                Text(AppStrings.usageReportEncodingFailed)
                    .foregroundStyle(DungeonPalette.danger)
            }
            .usageReportCard(border: DungeonPalette.danger.opacity(0.45))

        case .ready(let item):
            UsageReportInfoCard(
                title: AppStrings.usageReportIncludedTitle,
                description: AppStrings.usageReportIncludedDescription,
                systemImage: "checkmark.shield.fill",
                accent: DungeonPalette.victory,
                identifier: "usageReportIncludedCard",
                descriptionIdentifier: "usageReportIncludedDescription"
            )

            UsageReportInfoCard(
                title: AppStrings.usageReportExcludedTitle,
                description: AppStrings.usageReportExcludedDescription,
                systemImage: "shield.slash.fill",
                accent: DungeonPalette.ink.opacity(0.62),
                identifier: "usageReportExcludedCard",
                descriptionIdentifier: "usageReportExcludedDescription"
            )

            VStack(spacing: 8) {
                ShareLink(
                    item: item,
                    preview: SharePreview(
                        String(localized: AppStrings.usageReportFileTitle),
                        image: Image(systemName: "doc.text")
                    )
                ) {
                    Label(AppStrings.usageReportShareAction, systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PixelButtonStyle(
                    fill: DungeonPalette.hero,
                    foreground: colorScheme == .dark ? DungeonPalette.dungeon : .white
                ))
                .accessibilityIdentifier("usageReportShareButton")

                Text(AppStrings.usageReportShareNote)
                    .font(.caption)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func loadReport() {
        guard let export = loader.load(appVersion: appVersion, buildNumber: buildNumber) else {
            state = .unavailable
            return
        }
        do {
            state = .ready(UsageReportShareItem(data: try export.encodedJSON()))
        } catch {
            state = .encodingFailed
        }
    }
}

private struct UsageReportInfoCard: View {
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    let systemImage: String
    let accent: Color
    let identifier: String
    let descriptionIdentifier: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: PixelStyle.corner))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(DungeonPalette.ink)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(descriptionIdentifier)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .usageReportCard(border: accent.opacity(0.45))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private extension View {
    func usageReportCard(border: Color) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
            .overlay(
                RoundedRectangle(cornerRadius: PixelStyle.corner)
                    .stroke(border, lineWidth: PixelStyle.border)
            )
    }
}

private enum UsageReportShareState {
    case loading
    case unavailable
    case encodingFailed
    case ready(UsageReportShareItem)
}

nonisolated struct UsageReportShareItem: Transferable {
    static let fileName = "todo-slayer-usage-report-v1.json"

    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { item in
            item.data
        }
        .suggestedFileName(fileName)
    }
}
