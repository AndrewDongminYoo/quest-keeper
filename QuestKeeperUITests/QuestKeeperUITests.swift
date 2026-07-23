//
//  QuestKeeperUITests.swift
//  QuestKeeperUITests
//
//  Created by Dongmin yu on 7/8/26.
//

import XCTest

final class QuestKeeperUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testSwipeRightThenTapCompleteRemovesQuest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launch()

        let addButton = app.buttons["전투 추가"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()
        let titleField = app.textFields["제목"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Swipe completion UI test")
        let saveButton = app.buttons["저장"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let questTitle = app.staticTexts["Swipe completion UI test"]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(questTitle.waitForExistence(timeout: 3))

        questTitle.swipeRight()

        let completeButton = app.buttons["완료"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 1))
        completeButton.tap()

        XCTAssertTrue(questTitle.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testDailyFocusExplicitConfirmationAndCompletion() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemoryStore",
            "-onboardingVariant", "control",
            "-dailyFocusLoopEnabled",
        ]
        app.launch()

        for title in ["Focus 1", "Focus 2", "Focus 3", "Focus 4"] {
            createQuest(title: title, in: app)
        }

        let confirmButton = app.buttons["오늘 이대로 시작"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))

        app.buttons["핵심 퀘스트 수정"].tap()
        XCTAssertTrue(app.buttons["오늘 이대로 시작 (3/3)"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts
                .matching(NSPredicate(format: "label ENDSWITH %@", "분 남음"))
                .firstMatch
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "min"))
                .firstMatch
                .exists
        )
        tapFocusToggle(title: "Focus 3", in: app)
        XCTAssertTrue(app.buttons["오늘 이대로 시작 (2/3)"].waitForExistence(timeout: 2))
        tapFocusToggle(title: "Focus 4", in: app)
        app.buttons["오늘 이대로 시작 (3/3)"].tap()

        XCTAssertTrue(app.staticTexts["0/3 완료"].waitForExistence(timeout: 3))
        let remainingDisclosure = app.buttons["나머지 퀘스트 1개"]
        XCTAssertTrue(remainingDisclosure.waitForExistence(timeout: 2))

        let firstFocusQuest = app.staticTexts["Focus 1"]
        XCTAssertTrue(firstFocusQuest.waitForExistence(timeout: 2))
        revealCompletion(for: firstFocusQuest)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 68, dy: firstFocusQuest.frame.midY))
            .tap()

        XCTAssertTrue(app.staticTexts["1/3 완료"].waitForExistence(timeout: 4))
        XCTAssertTrue(firstFocusQuest.exists)
        XCTAssertTrue(app.staticTexts["Focus 1 완료"].waitForExistence(timeout: 2))

        app.buttons["나머지 퀘스트 1개"].tap()
        XCTAssertTrue(app.staticTexts["Focus 3"].waitForExistence(timeout: 2))

        app.buttons["핵심 퀘스트 수정"].tap()
        XCTAssertTrue(app.buttons["선택 완료 (3/3)"].waitForExistence(timeout: 2))
        tapFocusToggle(title: "Focus 4", in: app)
        XCTAssertTrue(app.buttons["선택 완료 (2/3)"].waitForExistence(timeout: 2))
        tapFocusToggle(title: "Focus 3", in: app)
        app.buttons["선택 완료 (3/3)"].tap()

        XCTAssertTrue(app.staticTexts["1/3 완료"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Focus 3"].exists)
        XCTAssertTrue(app.buttons["나머지 퀘스트 1개"].exists)
    }

    @MainActor
    func testDailyFocusRemainsDormantWithoutLaunchArgument() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launch()

        createQuest(title: "Ordinary flow", in: app)

        XCTAssertTrue(app.staticTexts["Ordinary flow"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["오늘 이대로 시작"].exists)
        XCTAssertFalse(app.buttons["핵심 퀘스트 수정"].exists)
    }

    @MainActor
    func testDailyFocusPersistsAcrossSameDayRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuestKeeperUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingStoreURL", directory.appendingPathComponent("store.sqlite").path,
            "-onboardingVariant", "control",
            "-dailyFocusLoopEnabled",
        ]
        app.launch()
        createQuest(title: "Relaunch 1", in: app)
        createQuest(title: "Relaunch 2", in: app)
        app.buttons["오늘 이대로 시작"].tap()
        XCTAssertTrue(app.staticTexts["0/2 완료"].waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["0/2 완료"].waitForExistence(timeout: 4))

        app.terminate()
        app.launch()

        XCTAssertTrue(app.staticTexts["0/2 완료"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Relaunch 1"].exists)
        XCTAssertFalse(app.buttons["오늘 이대로 시작"].exists)
        app.terminate()
    }

    @MainActor
    func testDailyFocusSelectionBoundsAreExplicit() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemoryStore",
            "-onboardingVariant", "control",
            "-dailyFocusLoopEnabled",
        ]
        app.launch()
        for title in ["Bounds 1", "Bounds 2", "Bounds 3", "Bounds 4"] {
            createQuest(title: title, in: app)
        }

        app.buttons["핵심 퀘스트 수정"].tap()
        XCTAssertTrue(app.buttons["오늘 이대로 시작 (3/3)"].waitForExistence(timeout: 2))
        XCTAssertFalse(focusToggle(title: "Bounds 4", in: app).isEnabled)
        for title in ["Bounds 1", "Bounds 2", "Bounds 3"] {
            tapFocusToggle(title: title, in: app)
        }
        let emptyConfirmation = app.buttons["오늘 이대로 시작 (0/3)"]
        XCTAssertTrue(emptyConfirmation.exists)
        XCTAssertFalse(emptyConfirmation.isEnabled)
    }

    @MainActor
    func testDailyFocusKeepsDailyGravesSeparate() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemoryStore",
            "-uiTestingDailyFocusGrave",
            "-onboardingVariant", "control",
            "-dailyFocusLoopEnabled",
        ]
        app.launch()
        createQuest(title: "오늘의 전투", in: app)

        XCTAssertTrue(app.staticTexts["오늘의 무덤"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["어제의 퀘스트"].exists)
        app.buttons["오늘 이대로 시작"].tap()
        XCTAssertTrue(app.staticTexts["오늘의 핵심 퀘스트"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["오늘의 무덤"].exists)
    }

    @MainActor
    func testDailyFocusRemainingQuestSupportsSwipeCompletion() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemoryStore",
            "-onboardingVariant", "control",
            "-dailyFocusLoopEnabled",
        ]
        app.launch()
        for title in ["Remaining 1", "Remaining 2", "Remaining 3", "Remaining 4"] {
            createQuest(title: title, in: app)
        }
        app.buttons["오늘 이대로 시작"].tap()
        app.buttons["나머지 퀘스트 1개"].tap()

        let remainingQuest = app.staticTexts["Remaining 4"]
        XCTAssertTrue(remainingQuest.waitForExistence(timeout: 2))
        remainingQuest.swipeRight()
        let completeButton = app.buttons["완료"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 1))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 68, dy: remainingQuest.frame.midY))
            .tap()

        XCTAssertTrue(remainingQuest.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0/3 완료"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func createQuest(title: String, in app: XCUIApplication) {
        let addButton = app.buttons["전투 추가"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let titleField = app.textFields["제목"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText(title)

        let saveButton = app.buttons["저장"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3))
    }

    @MainActor
    private func focusToggle(title: String, in app: XCUIApplication) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @MainActor
    private func tapFocusToggle(title: String, in app: XCUIApplication) {
        let toggle = focusToggle(title: title, in: app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    @MainActor
    private func revealCompletion(for questTitle: XCUIElement) {
        let start = questTitle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 180, dy: 0)))
    }

}
