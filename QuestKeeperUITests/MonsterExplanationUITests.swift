import XCTest

final class MonsterExplanationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingTheMonsterOpensTheExplanation() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["questRowTitle"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["monsterExplainButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["monsterExplanationDoneButton"].waitForExistence(timeout: 8))
    }

    /// Wrapping the glyph in a `Button` must not replace its identity announcement with just
    /// the action hint. `AppStrings.a11yMonsterLevel` always renders "<몬스터> 레벨 <n>", so
    /// asserting on "레벨" ties this to that format without hardcoding which monster the
    /// screenshot fixture happens to seed.
    @MainActor
    func testMonsterButtonLabelStillAnnouncesTheMonsterIdentity() throws {
        let app = launch()
        let button = app.buttons["monsterExplainButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8))
        XCTAssertTrue(
            button.label.contains("레벨"),
            "expected the monster's name/level in the accessibility label, got: \(button.label)"
        )
    }

    /// The explain button sits inside a row that already owns a tap gesture and a drag
    /// gesture. This asserts the drag survived.
    @MainActor
    func testSwipeToRevealStillWorks() throws {
        let app = launch()
        let row = app.staticTexts["questRowTitle"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.swipeRight()
        XCTAssertTrue(app.buttons["완료"].firstMatch.waitForExistence(timeout: 4))
    }

    /// `testSwipeToRevealStillWorks` above drags from the row's left (title) column, which
    /// never touches the new button. This drags starting from inside the button's own 44pt
    /// hit region — the exact spot the regression risk was about — to prove the button does
    /// not swallow the parent row's `simultaneousGesture(DragGesture)`.
    @MainActor
    func testSwipeToRevealStillWorksWhenStartingOnTheMonsterButton() throws {
        let app = launch()
        let button = app.buttons["monsterExplainButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8))

        let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.staticTexts["questRowTitle"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.buttons["완료"].firstMatch.waitForExistence(timeout: 4))
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += uiTestKoreanLocaleArguments
        app.launchArguments += [
            "-uiTestingInMemoryStore",
            "-onboardingVariant", "control",
            "-storeScreenshotFixture",
        ]
        app.launch()
        return app
    }
}
