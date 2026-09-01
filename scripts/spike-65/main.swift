import Foundation
import SwiftData

// Two-process reproduction harness for quest-keeper issue #65.
//
// Roles:
//   seed  <storeURL>                          -> creates one pending quest, prints its UUID
//   a     <storeURL> <gateDir> <questID> <arm>-> the shortcut side: open, (arm 1) fetch, wait, fetch
//   b     <storeURL> <gateDir> <questID>      -> the widget side: wait, open, commit completedAt
//
// Arm 1 mirrors QuestShortcutCreationCoordinator.create, which reads the board for the
// reengagement refresh before it reads the widget payload. Arm 2 skips that first fetch so the
// payload read happens on a context that registered nothing.

func modelSchema() -> Schema {
    Schema([
        Quest.self,
        RetentionInstallation.self,
        RetentionEvent.self,
        ExperimentAssignment.self,
        DailyFocusSelection.self,
        RoutineRule.self,
        RoutineCompletion.self,
    ])
}

func makeContainer(_ url: URL) throws -> ModelContainer {
    let schema = modelSchema()
    return try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, url: url)]
    )
}

func stamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func log(_ marker: String, _ message: String) {
    print("[\(marker)] \(stamp(Date())) \(message)")
    fflush(stdout)
}

func describe(_ date: Date?) -> String {
    date.map { stamp($0) } ?? "nil"
}

func touch(_ url: URL) throws {
    try Data().write(to: url)
}

func waitForFile(_ url: URL, timeout: TimeInterval = 60) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: url.path) { return true }
        usleep(5000)
    }
    return false
}

func fetchQuest(_ context: ModelContext, id: UUID) throws -> Quest? {
    let descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })
    return try context.fetch(descriptor).first
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: harness <role> <storeURL> [...]\n".utf8))
    exit(2)
}
let role = arguments[1]
let storeURL = URL(fileURLWithPath: arguments[2])

switch role {
case "seed":
    let container = try makeContainer(storeURL)
    let context = ModelContext(container)
    let quest = Quest(
        title: "spike-65",
        deadline: Date().addingTimeInterval(86400),
        importance: .medium
    )
    context.insert(quest)
    try context.save()
    print(quest.id.uuidString)

case "a":
    let gateDir = URL(fileURLWithPath: arguments[3])
    let questID = UUID(uuidString: arguments[4])!
    let arm = arguments[5]
    let aReady = gateDir.appending(path: "a-ready")
    let bDone = gateDir.appending(path: "b-done")

    let container = try makeContainer(storeURL)
    log("A", "open container arm=\(arm) url=\(storeURL.path)")
    let context = ModelContext(container)

    // QuestStoreActor.create — the shortcut inserts and saves its own quest on this context before
    // anything else runs, so the context is not pristine when the later reads happen.
    let created = Quest(
        title: "spike-65-created",
        deadline: Date().addingTimeInterval(172_800),
        importance: .low
    )
    context.insert(created)
    try context.save()
    log("A", "create quest=\(created.id) committed")

    // Retained across the gate so the object-level read below is a genuine no-refetch read.
    var retained: Quest?
    if arm == "1" {
        // QuestStoreActor.snapshots() — the readBoard fetch handed to syncAndRefreshReengagement.
        let all = try context.fetch(FetchDescriptor<Quest>())
        retained = all.first { $0.id == questID }
        log("A", "fetch#1 quest=\(questID) completedAt=\(describe(retained?.completedAt)) boardCount=\(all.count)")
    } else {
        log("A", "fetch#1 skipped (arm 2)")
    }

    try touch(aReady)
    guard waitForFile(bDone) else {
        log("A", "TIMEOUT waiting for b-done")
        exit(3)
    }

    // Negative control: read the already-registered object without re-fetching. If this reports the
    // completion too, the harness has no way to observe staleness at all and a FRESH verdict below
    // would be vacuous.
    if let retained {
        log("A", "objectRead quest=\(questID) completedAt=\(describe(retained.completedAt))")
        print(retained.completedAt == nil ? "OBJECT=STALE" : "OBJECT=FRESH")
    }

    // QuestStoreActor.snapshotPayload — the fetch WidgetDungeonPayload.make is derived from.
    let board = try context.fetch(FetchDescriptor<Quest>())
    let after = board.first { $0.id == questID }
    log("A", "fetch#2 quest=\(questID) completedAt=\(describe(after?.completedAt)) boardCount=\(board.count)")
    print(after?.completedAt == nil ? "RESULT=STALE" : "RESULT=FRESH")

case "b":
    let gateDir = URL(fileURLWithPath: arguments[3])
    let questID = UUID(uuidString: arguments[4])!
    let aReady = gateDir.appending(path: "a-ready")
    let bDone = gateDir.appending(path: "b-done")

    guard waitForFile(aReady) else {
        log("B", "TIMEOUT waiting for a-ready")
        exit(3)
    }
    let container = try makeContainer(storeURL)
    let context = ModelContext(container)
    guard let quest = try fetchQuest(context, id: questID) else {
        log("B", "quest not found \(questID)")
        exit(4)
    }
    let now = Date()
    quest.completedAt = now
    try context.save()
    log("B", "commit quest=\(questID) completedAt=\(describe(now))")
    try touch(bDone)

default:
    FileHandle.standardError.write(Data("unknown role \(role)\n".utf8))
    exit(2)
}
