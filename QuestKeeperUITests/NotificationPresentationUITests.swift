import XCTest

@MainActor
final class NotificationPresentationUITests: XCTestCase {
    private let routedQuestID = "00000000-0000-0000-0000-000000000101"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAboutSheetClosesBeforeOpeningNotificationQuest() {
        let app = launch()

        let aboutButton = app.buttons["aboutButton"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 3))
        aboutButton.tap()
        XCTAssertTrue(app.buttons["aboutDoneButton"].waitForExistence(timeout: 3))

        assertNotificationQuestOpens(in: app)
        XCTAssertFalse(app.buttons["aboutDoneButton"].exists)
    }

    func testDailyFocusEditorDefersNotificationQuestUntilDismissal() {
        let app = launch(additionalArguments: ["-dailyFocusLoopEnabled"])

        let editButton = app.buttons["focusPlanEditButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()
        XCTAssertTrue(app.buttons["dailyFocusSelectionConfirmButton"].waitForExistence(timeout: 3))

        assertNotificationRouteWasDelivered(in: app)
        XCTAssertFalse(app.navigationBars["퀘스트 기록"].exists)
        XCTAssertTrue(app.buttons["dailyFocusSelectionConfirmButton"].exists)
        app.buttons["취소"].tap()
        assertNotificationQuestOpens(in: app)
    }

    func testRoutineEditorPreservesInputAndDefersNotificationQuestUntilDismissal() {
        let app = launch(additionalArguments: ["-uiTestingRoutineFixture"])

        let addButton = app.buttons["routineHomeAddButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()
        let titleField = app.textFields["routineEditorTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Keep this draft")

        assertNotificationRouteWasDelivered(in: app)
        XCTAssertFalse(app.navigationBars["퀘스트 기록"].exists)
        XCTAssertEqual(titleField.value as? String, "Keep this draft")
        app.buttons["취소"].tap()
        assertNotificationQuestOpens(in: app)
    }

    func testQuestEditorFromDetailPreservesInputAndDefersNotificationQuestUntilDismissal() {
        let app = launch(additionalArguments: [
            "-uiTestingNotificationRouteDelaySeconds", "8",
        ])

        let otherQuest = app.staticTexts["회복 퀘스트 2"]
        XCTAssertTrue(otherQuest.waitForExistence(timeout: 3))
        otherQuest.tap()
        let editButton = app.buttons["questDetailEditButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText(" 보존")

        assertNotificationRouteWasDelivered(in: app)
        XCTAssertTrue(titleField.exists)
        XCTAssertEqual(titleField.value as? String, "회복 퀘스트 2 보존")
        app.buttons["취소"].tap()
        assertNotificationQuestOpens(in: app)
    }

    private func assertNotificationRouteWasDelivered(in app: XCUIApplication) {
        let marker = app.descendants(matching: .any)["uiTestingNotificationRouteDelivered"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
    }

    private func assertNotificationQuestOpens(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["퀘스트 기록"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["회복 퀘스트 1"].exists)
    }

    private func launch(additionalArguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = uiTestKoreanLocaleArguments + [
            "-uiTestingInMemoryStore",
            "-uiTestingRecoveryFixture",
            "-uiTestingNotificationRouteQuestID", routedQuestID,
            "-onboardingVariant", "control",
        ] + additionalArguments
        app.launch()
        return app
    }
}
