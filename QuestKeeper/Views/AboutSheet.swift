//
//  AboutSheet.swift
//  QuestKeeper
//
//  Spec 020 — version, legal links, and the tip jar. Built on the HeroAppearanceSheet
//  shape so the two sheets read as one surface.
//

import SwiftUI

struct AboutSheet: View {
    @State private var model: TipJarModel

    @Environment(\.dismiss) private var dismiss

    init(store: TipJarStore) {
        _model = State(initialValue: TipJarModel(store: store))
    }

    /// 번들이 표시용으로 들고 있는 이름. 코드에 상수로 적지 않는다 — 로케일별 이름과
    /// 리브랜딩이 모두 번들 쪽에서 결정된다.
    private var appName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? Brand.displayName
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    /// 랜딩 사이트가 로케일별 경로를 쓰므로 언어에 맞춰 고른다.
    /// `Locale.current`가 아니라 번들이 실제로 고른 로컬라이제이션을 읽는다 — 기기 언어가
    /// 지원 목록에 없어 한국어로 폴백한 경우나 앱별 언어 설정을 쓴 경우, 둘은 서로 다르다.
    private var privacyURL: URL? {
        let localization = Bundle.main.preferredLocalizations.first ?? "en"
        let language = localization.hasPrefix("ko") ? "ko" : "en"
        return URL(string: "https://quest.donminzzi.kr/\(language)/privacy")
    }

    private var repositoryURL: URL? {
        URL(string: "https://github.com/AndrewDongminYoo/quest-keeper")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: appName)
                        .font(.headline)
                        .foregroundStyle(DungeonPalette.ink)
                    LabeledContent(String(localized: AppStrings.aboutVersionLabel), value: versionText)
                }
                .listRowBackground(DungeonPalette.stone)

                Section {
                    if let privacyURL {
                        Link(destination: privacyURL) {
                            Text(AppStrings.aboutPrivacyPolicy)
                        }
                    }
                    if let repositoryURL {
                        Link(destination: repositoryURL) {
                            Text(AppStrings.aboutSourceRepository)
                        }
                    }
                }
                .listRowBackground(DungeonPalette.stone)

                tipSection
                    .listRowBackground(DungeonPalette.stone)
            }
            .formStyle(.grouped)
            .navigationTitle(AppStrings.aboutNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(DungeonPalette.dungeon)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.aboutDoneAction) { dismiss() }
                        .accessibilityIdentifier("aboutDoneButton")
                }
            }
            .task { await model.load() }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var tipSection: some View {
        Section {
            switch model.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)

            case .loaded(let items):
                ForEach(items) { item in
                    tipRow(item)
                }

            case .failed:
                // 시트의 나머지는 그대로 두고 이 줄만 재시도를 제안한다.
                Text(AppStrings.aboutTipLoadFailed)
                    .foregroundStyle(DungeonPalette.ink)
                Button(AppStrings.aboutTipRetryAction) {
                    Task { await model.load() }
                }
                .accessibilityIdentifier("aboutTipRetryButton")
            }
        } header: {
            Text(AppStrings.aboutTipSection)
        } footer: {
            // 감사 문구는 검증된 구매 뒤에만, 실패 문구는 결제가 성립하지 못했을 때만 나타난다.
            // 거절에는 아무 문구도 붙지 않는다.
            switch model.purchaseNote {
            case .thanks:
                Text(AppStrings.aboutTipThanks).foregroundStyle(DungeonPalette.victory)
            case .failed:
                Text(AppStrings.aboutTipFailed).foregroundStyle(DungeonPalette.danger)
            case .none:
                Text(AppStrings.aboutTipNote).foregroundStyle(DungeonPalette.ink.opacity(0.7))
            }
        }
    }

    private func tipRow(_ item: TipJarItem) -> some View {
        Button {
            Task { await model.tip(item.tier) }
        } label: {
            LabeledContent(item.displayName) {
                if model.purchasingTier == item.tier {
                    ProgressView()
                } else {
                    Text(item.displayPrice)
                        .monospacedDigit()
                }
            }
        }
        .disabled(model.purchasingTier != nil)
        .accessibilityIdentifier("aboutTipButton.\(item.tier.rawValue)")
    }
}

#Preview {
    AboutSheet(store: StoreKitTipJarStore())
}
