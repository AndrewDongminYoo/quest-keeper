//
//  ContentView.swift
//  QuestKeeper
//
//  Phase 2 — root: hero header + dungeon/daily-grave sections. Wires scenePhase state-replay and
//  TimelineView live derivation to the Phase 1 layer. See docs/specs/003-crud-hero-view.md.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Quest.deadline) private var quests: [Quest]

    /// A stored fact: when the app was last foregrounded (Phase 4 moves this to the App Group).
    @AppStorage("lastOpenedTIRD") private var lastOpenedRaw: Double = 0

    /// Transient: the deaths to mourn this activation. Drives the "꿱" frame, then resets.
    @State private var pendingDeaths: [UUID] = []
    @State private var route: EditorRoute?
    @State private var notificationAuthorization: QuestNotificationAuthorization = .notDetermined
    @State private var mourningTask: Task<Void, Never>?

    private let notificationService: QuestNotificationService
    private let notificationRouteStore: NotificationRouteStore

    init(
        notificationService: QuestNotificationService = .shared,
        notificationRouteStore: NotificationRouteStore = NotificationRouteStore()
    ) {
        self.notificationService = notificationService
        self.notificationRouteStore = notificationRouteStore
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let now = context.date
                let snapshots = quests.map(\.snapshot)
                let state = HeroDerivation.state(quests: snapshots, now: now, lastOpened: now)
                // Derived membership — recomputed every tick, never queried (outcome depends on `now`).
                let pending = quests.filter { $0.snapshot.outcome(at: now) == .pending }
                let dailyGraves = quests.filter { $0.snapshot.isVisibleDailyGrave(at: now) }

                List {
                    HeroHeader(state: state, isMourning: !pendingDeaths.isEmpty)
                    if notificationAuthorization == .denied {
                        notificationPermissionSection
                    }
                    QuestListSections(
                        pending: pending,
                        dailyGraves: dailyGraves,
                        now: now,
                        onComplete: complete,
                        onRetryTomorrow: retryTomorrow,
                        onDelete: delete,
                        onEdit: { route = .edit($0) }
                    )
                }
                .scrollContentBackground(.hidden)
                .background(Color(red: 0.11, green: 0.09, blue: 0.15))
                .overlay {
                    if pending.isEmpty && dailyGraves.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "scroll")
                                .font(.largeTitle)
                            Text("퀘스트가 없습니다")
                                .font(.headline)
                            Text("오른쪽 위 + 로 오늘의 퀘스트를 추가하세요.")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("QUEST KEEPER")
            .toolbarBackground(Color(red: 0.11, green: 0.09, blue: 0.15), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { route = .create } label: {
                        Label("전투 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $route) { route in
                switch route {
                case .create:
                    QuestEditor(
                        quest: nil,
                        notificationService: notificationService,
                        onAuthorizationChange: { notificationAuthorization = $0 }
                    )
                case .edit(let quest):
                    QuestEditor(
                        quest: quest,
                        notificationService: notificationService,
                        onAuthorizationChange: { notificationAuthorization = $0 }
                    )
                case .dailyGrave(let quest):
                    QuestResolutionView(quest: quest, now: .now) {
                        retryTomorrow(quest)
                        self.route = nil
                    }
                case .resolved(let quest):
                    QuestResolutionView(quest: quest, now: .now)
                }
            }
            .task {
                notificationAuthorization = await notificationService.authorizationStatus()
            }
            .onChange(of: notificationRouteStore.pendingQuestID, initial: true) { _, questID in
                consumeNotificationRoute(questID)
            }
            .onChange(of: quests.map(\.id), initial: true) { _, _ in
                consumeNotificationRoute(notificationRouteStore.pendingQuestID)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { onBecameActive(now: .now) }
        }
    }

    private var notificationPermissionSection: some View {
        Section {
            Button { openNotificationSettings() } label: {
                Label("알림 꺼짐", systemImage: "bell.slash")
            }
        } footer: {
            Text("마감 알림을 받으려면 설정에서 QuestKeeper 알림을 켜세요.")
        }
    }

    // MARK: - Lifecycle

    private func onBecameActive(now: Date) {
        let previous = lastOpenedRaw == 0 ? nil : Date(timeIntervalSinceReferenceDate: lastOpenedRaw)
        let (deaths, newLastOpened) = reconstructOnActivation(
            quests: quests.map(\.snapshot), now: now, previousLastOpened: previous)
        lastOpenedRaw = newLastOpened.timeIntervalSinceReferenceDate

        Task { @MainActor in
            notificationAuthorization = await notificationService.reconcile(quests: quests, now: now)
        }

        guard !deaths.isEmpty else { return }
        withAnimation { pendingDeaths = deaths }
        // Play once, then settle — otherwise the mourning frame latches until the next activation.
        mourningTask?.cancel()
        mourningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(GameBalance.mourningDuration))
            guard !Task.isCancelled else { return }
            withAnimation { pendingDeaths = [] }
        }
    }

    // MARK: - Fact mutations

    private func complete(_ quest: Quest) {
        let questID = quest.id
        QuestActions.complete(quest, at: .now)
        Task { @MainActor in
            await notificationService.cancel(questID: questID)
        }
    }

    private func retryTomorrow(_ quest: Quest) {
        let now = Date.now
        QuestActions.retryTomorrow(quest, now: now)
        Task { @MainActor in
            let authorization = await notificationService.sync(quest: quest, now: now)
            notificationAuthorization = authorization
        }
    }

    private func delete(_ quest: Quest) {
        guard QuestActions.canDelete(quest.snapshot, at: .now) else { return }
        let questID = quest.id
        modelContext.delete(quest)
        Task { @MainActor in
            await notificationService.cancel(questID: questID)
        }
    }

    private func consumeNotificationRoute(_ questID: UUID?) {
        guard let questID else { return }
        guard let quest = quests.first(where: { $0.id == questID }) else {
            print("Notification route is waiting for quest: \(questID)")
            return
        }

        let now = Date.now
        switch notificationDestination(for: quest.snapshot, now: now) {
        case .edit:
            route = .edit(quest)
        case .dailyGrave:
            route = .dailyGrave(quest)
        case .resolved:
            route = .resolved(quest)
        }
        notificationRouteStore.clear()
    }

    private func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

/// Which quest, if any, the editor sheet is editing. `.create` inserts a new one.
enum EditorRoute: Identifiable {
    case create
    case edit(Quest)
    case dailyGrave(Quest)
    case resolved(Quest)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let quest): quest.id.uuidString
        case .dailyGrave(let quest): "daily-grave-\(quest.id.uuidString)"
        case .resolved(let quest): "resolved-\(quest.id.uuidString)"
        }
    }
}

nonisolated enum NotificationQuestDestination: Equatable {
    case edit
    case dailyGrave
    case resolved
}

nonisolated func notificationDestination(for snapshot: QuestSnapshot, now: Date) -> NotificationQuestDestination {
    switch snapshot.outcome(at: now) {
    case .pending:
        return .edit
    case .grave where snapshot.isVisibleDailyGrave(at: now):
        return .dailyGrave
    case .victory, .grave:
        return .resolved
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Quest.self, inMemory: true)
}
