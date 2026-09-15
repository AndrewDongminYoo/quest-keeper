import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct UsageReportShareSheet: View {
    let loader: UsageReportExportLoader
    let appVersion: String
    let buildNumber: String

    @Environment(\.dismiss) private var dismiss
    @State private var state: UsageReportShareState = .loading

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(AppStrings.usageReportIntro)
                        .foregroundStyle(DungeonPalette.ink)
                }
                .listRowBackground(DungeonPalette.stone)

                reportContent
            }
            .formStyle(.grouped)
            .navigationTitle(AppStrings.usageReportNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
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

    @ViewBuilder
    private var reportContent: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowBackground(DungeonPalette.stone)

        case .unavailable:
            Section {
                Text(AppStrings.usageReportUnavailable)
                    .foregroundStyle(DungeonPalette.ink)
                    .accessibilityIdentifier("usageReportUnavailableMessage")
            }
            .listRowBackground(DungeonPalette.stone)

        case .encodingFailed:
            Section {
                Text(AppStrings.usageReportEncodingFailed)
                    .foregroundStyle(DungeonPalette.danger)
            }
            .listRowBackground(DungeonPalette.stone)

        case .ready(let item):
            Section {
                Text(AppStrings.usageReportIncludedDescription)
                    .foregroundStyle(DungeonPalette.ink)
                    .accessibilityIdentifier("usageReportIncludedDescription")
            } header: {
                Text(AppStrings.usageReportIncludedTitle)
            }
            .listRowBackground(DungeonPalette.stone)

            Section {
                Text(AppStrings.usageReportExcludedDescription)
                    .foregroundStyle(DungeonPalette.ink)
                    .accessibilityIdentifier("usageReportExcludedDescription")
            } header: {
                Text(AppStrings.usageReportExcludedTitle)
            }
            .listRowBackground(DungeonPalette.stone)

            Section {
                ShareLink(
                    item: item,
                    preview: SharePreview(
                        String(localized: AppStrings.usageReportFileTitle),
                        image: Image(systemName: "doc.text")
                    )
                ) {
                    Label(AppStrings.usageReportShareAction, systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("usageReportShareButton")
            } footer: {
                Text(AppStrings.usageReportShareNote)
            }
            .listRowBackground(DungeonPalette.stone)
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
