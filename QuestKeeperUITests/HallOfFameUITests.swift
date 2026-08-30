import XCTest

@MainActor
final class HallOfFameUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCurrentVictoriesOpenFromTheHUDAndLongTitleWraps() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + ["-uiTestingHallOfFameFixture"])
        let entry = app.buttons["hallOfFameButton"]

        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
        entry.tap()

        XCTAssertTrue(app.navigationBars["전리품 창고"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["hallOfFameQuest-00000000-0000-0000-0000-000000000201"].waitForExistence(timeout: 3))
        let longTitle = app.staticTexts["hallOfFameQuest-00000000-0000-0000-0000-000000000202"]
        XCTAssertTrue(longTitle.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(longTitle.frame.height, 20)
    }

    func testEmptyHallOfFameIsIntentional() {
        let app = launch(arguments: uiTestKoreanLocaleArguments)
        let entry = app.buttons["hallOfFameButton"]

        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()

        XCTAssertTrue(app.staticTexts["hallOfFameEmptyState"].waitForExistence(timeout: 3))
    }

    func testEnglishSheetTitleAndLongTitleRender() {
        let app = launch(arguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestingHallOfFameFixture"])
        let entry = app.buttons["hallOfFameButton"]

        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()

        XCTAssertTrue(app.navigationBars["Hall of Fame"].waitForExistence(timeout: 3))
        let longTitle = app.staticTexts["hallOfFameQuest-00000000-0000-0000-0000-000000000202"]
        XCTAssertTrue(longTitle.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(longTitle.frame.height, 20)
    }

    func testLargestDynamicTypeKeepsKoreanHallOfFameAccessible() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-uiTestingHallOfFameFixture",
        ])
        let entry = app.buttons["hallOfFameButton"]
        let appearance = app.buttons["heroAppearanceButton"]
        let about = app.buttons["aboutButton"]
        let add = app.buttons["questAddButton"]

        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
        XCTAssertTrue(appearance.exists)
        XCTAssertTrue(about.exists)
        XCTAssertTrue(add.exists)
        XCTAssertFalse(entry.frame.intersects(appearance.frame), "\(entry.frame) intersects \(appearance.frame)")
        XCTAssertFalse(entry.frame.intersects(about.frame), "\(entry.frame) intersects \(about.frame)")
        XCTAssertFalse(entry.frame.intersects(add.frame), "\(entry.frame) intersects \(add.frame)")
        entry.tap()

        XCTAssertTrue(app.navigationBars["전리품 창고"].waitForExistence(timeout: 3))
        let longTitle = app.staticTexts["hallOfFameQuest-00000000-0000-0000-0000-000000000202"]
        XCTAssertTrue(longTitle.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(longTitle.frame.height, 20)
        XCTAssertTrue(app.buttons["hallOfFameCloseButton"].waitForExistence(timeout: 3))
    }

    func testLargestDynamicTypeKeepsEnglishHallOfFameAccessible() {
        let app = launch(arguments: [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-uiTestingHallOfFameFixture",
        ])
        let entry = app.buttons["hallOfFameButton"]

        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()

        XCTAssertTrue(app.navigationBars["Hall of Fame"].waitForExistence(timeout: 3))
        let longTitle = app.staticTexts["hallOfFameQuest-00000000-0000-0000-0000-000000000202"]
        XCTAssertTrue(longTitle.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(longTitle.frame.height, 20)
        XCTAssertTrue(app.buttons["hallOfFameCloseButton"].waitForExistence(timeout: 3))
    }

    private func launch(arguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launch()
        return app
    }
}
