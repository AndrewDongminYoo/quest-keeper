import XCTest

@MainActor
final class WeeklyReviewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCardReportsLastWeekAndReachesTheQuestEditor() {
        let app = weeklyReviewApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["지난주 전과"].waitForExistence(timeout: 3))
        // The fixture seeds three victories over two days in the reviewed week and one the week
        // before it. The two figures are merged into one accessibility element on purpose — three
        // bare numerals read out of context are not usable — so this asserts the merged sentence
        // rather than the individual numbers, which the merge makes unqueryable.
        let stats = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "지난주 승리 3회, 활동한 날 2일.")
        ).firstMatch
        XCTAssertTrue(stats.exists)
        XCTAssertTrue(app.staticTexts["그 전 주보다 2회 많아요."].exists)
        // Voice: the card names what was done, never what was missed.
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "실패")
        ).firstMatch.exists)

        app.buttons["weeklyReviewPlanButton"].tap()
        XCTAssertTrue(app.textFields["제목"].waitForExistence(timeout: 3))
    }

    func testDismissClearsTheCardForTheReviewedWeek() {
        let app = weeklyReviewApp()
        app.launch()

        XCTAssertTrue(app.buttons["weeklyReviewDismissButton"].waitForExistence(timeout: 3))
        app.buttons["weeklyReviewDismissButton"].tap()

        XCTAssertFalse(app.staticTexts["지난주 전과"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["weeklyReviewPlanButton"].exists)
    }

    private func weeklyReviewApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = uiTestKoreanLocaleArguments + [
            "-uiTestingInMemoryStore",
            "-uiTestingWeeklyReviewFixture",
        ]
        return app
    }
}
