//
//  ContentView.swift
//  QuestKeeper
//
//  Phase 2 — root: hero header + Active/Graveyard sections. Wires scenePhase state-replay and
//  TimelineView live derivation to the Phase 1 layer. See docs/specs/003-crud-hero-view.md.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Quest.deadline) private var quests: [Quest]

    /// A stored fact: when the app was last foregrounded (Phase 4 moves this to the App Group).
    @AppStorage("lastOpenedTIRD") private var lastOpenedRaw: Double = 0

    /// Transient: the deaths to mourn this activation. Drives the "꿱" frame, then resets.
    @State private var pendingDeaths: [UUID] = []
    @State private var route: EditorRoute?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let now = context.date
                let snapshots = quests.map(\.snapshot)
                let state = HeroDerivation.state(quests: snapshots, now: now, lastOpened: now)
                // Derived membership — recomputed every tick, never queried (outcome depends on `now`).
                let pending = quests.filter { $0.snapshot.outcome(at: now) == .pending }
                let graves = quests.filter { $0.snapshot.outcome(at: now) == .grave }

                List {
                    HeroHeader(state: state, isMourning: !pendingDeaths.isEmpty)
                    QuestListSections(
                        pending: pending,
                        graves: graves,
                        now: now,
                        onComplete: complete,
                        onDelete: delete,
                        onEdit: { route = .edit($0) }
                    )
                }
                .overlay {
                    if pending.isEmpty && graves.isEmpty {
                        ContentUnavailableView("퀘스트가 없습니다", systemImage: "scroll",
                                               description: Text("오른쪽 위 + 로 오늘의 퀘스트를 추가하세요."))
                    }
                }
            }
            .navigationTitle("QuestKeeper")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { route = .create } label: {
                        Label("추가", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $route) { route in
                QuestEditor(quest: route.editableQuest)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { onBecameActive(now: .now) }
        }
    }

    // MARK: - Lifecycle

    private func onBecameActive(now: Date) {
        let previous = lastOpenedRaw == 0 ? nil : Date(timeIntervalSinceReferenceDate: lastOpenedRaw)
        let (deaths, newLastOpened) = reconstructOnActivation(
            quests: quests.map(\.snapshot), now: now, previousLastOpened: previous)
        lastOpenedRaw = newLastOpened.timeIntervalSinceReferenceDate

        guard !deaths.isEmpty else { return }
        withAnimation { pendingDeaths = deaths }
        // Play once, then settle — otherwise the mourning frame latches until the next activation.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(GameBalance.mourningDuration))
            withAnimation { pendingDeaths = [] }
        }
    }

    // MARK: - Fact mutations

    private func complete(_ quest: Quest) {
        QuestActions.complete(quest, at: .now)
    }

    private func delete(_ quest: Quest) {
        guard QuestActions.canDelete(quest.snapshot, at: .now) else { return }
        modelContext.delete(quest)
    }
}

/// Which quest, if any, the editor sheet is editing. `.create` inserts a new one.
enum EditorRoute: Identifiable {
    case create
    case edit(Quest)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let quest): quest.id.uuidString
        }
    }

    var editableQuest: Quest? {
        if case .edit(let quest) = self { quest } else { nil }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Quest.self, inMemory: true)
}
