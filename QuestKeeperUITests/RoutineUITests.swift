import XCTest

@MainActor
final class RoutineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCompletionHidesTheFixedRosterWithoutReplacementAndKeepsRulesManageable() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + ["-uiTestingRoutineFixture"])

        let initialActions = completionButtons(in: app)
        XCTAssertEqual(initialActions.count, 2)

        let firstAction = app.buttons[initialActions.element(boundBy: 0).identifier]
        firstAction.tap()
        waitForDisappearance(of: firstAction)
        XCTAssertEqual(completionButtons(in: app).count, 1)

        let secondAction = app.buttons[completionButtons(in: app).element(boundBy: 0).identifier]
        secondAction.tap()
        waitForDisappearance(of: secondAction)
        XCTAssertEqual(completionButtons(in: app).count, 0)

        let manageButton = app.buttons["routineHomeManageButton"]
        XCTAssertTrue(manageButton.waitForExistence(timeout: 3))
        manageButton.tap()

        XCTAssertTrue(app.navigationBars["루틴 관리"].waitForExistence(timeout: 3))
        let firstRule = app.buttons["routineManage-00000000-0000-0000-0000-000000000301"]
        XCTAssertTrue(firstRule.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["routineManage-00000000-0000-0000-0000-000000000302"].exists)
        XCTAssertTrue(app.buttons["routineManage-00000000-0000-0000-0000-000000000303"].exists)

        let deleteButton = app.buttons["routineDelete-00000000-0000-0000-0000-000000000301"]
        XCTAssertTrue(deleteButton.exists)
        deleteButton.tap()
        waitForDisappearance(of: firstRule)
    }

    func testBoardCanCreateAnEnglishRoutine() {
        let app = launch(arguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])

        let addButton = app.buttons["routineHomeAddButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        XCTAssertTrue(app.navigationBars["New routine"].waitForExistence(timeout: 3))
        let titleField = app.textFields["routineEditorTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Water plants")
        app.buttons["routineEditorSaveButton"].tap()

        XCTAssertTrue(app.staticTexts["Water plants"].waitForExistence(timeout: 3))
        XCTAssertEqual(completionButtons(in: app).count, 1)
    }

    func testRoutineSectionDoesNotDisplaceDailyFocusRecommendation() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + [
            "-storeScreenshotFixture",
            "-dailyFocusLoopEnabled",
            "-uiTestingRoutineFixture",
        ])

        XCTAssertTrue(app.buttons["focusPlanConfirmButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["routineHomeManageButton"].waitForExistence(timeout: 3))
    }

    func testRoutineEditorClosesBeforeForegroundContainerRefresh() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + ["-uiTestingRoutineFixture"])
        let manageButton = app.buttons["routineHomeManageButton"]

        XCTAssertTrue(manageButton.waitForExistence(timeout: 3))
        manageButton.tap()
        let routine = app.buttons["routineManage-00000000-0000-0000-0000-000000000301"]
        XCTAssertTrue(routine.waitForExistence(timeout: 3))
        routine.tap()
        let titleField = app.textFields["routineEditorTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()

        let dismissal = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: titleField
        )
        wait(for: [dismissal], timeout: 3)
    }

    func testRoutineManagementClosesBeforeForegroundContainerRefresh() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + ["-uiTestingRoutineFixture"])
        let manageButton = app.buttons["routineHomeManageButton"]

        XCTAssertTrue(manageButton.waitForExistence(timeout: 3))
        manageButton.tap()
        let routine = app.buttons["routineManage-00000000-0000-0000-0000-000000000301"]
        XCTAssertTrue(routine.waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()

        let dismissal = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: routine
        )
        wait(for: [dismissal], timeout: 3)
    }

    private func completionButtons(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "routineComplete-"))
    }

    private func waitForDisappearance(of element: XCUIElement) {
        let disappearance = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: element
        )
        wait(for: [disappearance], timeout: 3)
    }

    private func launch(arguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launch()
        return app
    }
}
