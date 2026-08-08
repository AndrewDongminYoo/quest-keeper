import XCTest

final class StoreScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStoreScreenshots() throws {
        XCUIDevice.shared.orientation = .portrait

        let populated = launch(arguments: ["-storeScreenshotFixture"])
        XCTAssertTrue(populated.staticTexts["앱 스크린샷 준비하기"].waitForExistence(timeout: 4))
        snapshot("01-dungeon", timeWaitingForIdle: 0)
        populated.terminate()

        let focus = launch(arguments: ["-storeScreenshotFixture", "-dailyFocusLoopEnabled"])
        XCTAssertTrue(focus.buttons["오늘 이대로 시작"].waitForExistence(timeout: 4))
        snapshot("02-focus-plan", timeWaitingForIdle: 0)
        focus.buttons["핵심 퀘스트 수정"].tap()
        XCTAssertTrue(focus.navigationBars["핵심 퀘스트 수정"].waitForExistence(timeout: 4))
        snapshot("03-focus-selection", timeWaitingForIdle: 0)
        focus.terminate()

        let grave = launch(arguments: ["-storeScreenshotFixture", "-uiTestingDailyFocusGrave"])
        XCTAssertTrue(grave.staticTexts["오늘의 무덤"].waitForExistence(timeout: 4))
        snapshot("04-daily-grave", timeWaitingForIdle: 0)
        grave.terminate()

        let editor = launch(arguments: [])
        let addButton = editor.buttons["전투 추가"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 4))
        addButton.tap()
        XCTAssertTrue(editor.navigationBars["새 퀘스트"].waitForExistence(timeout: 3))
        snapshot("05-quest-editor", timeWaitingForIdle: 0)
        editor.terminate()

        let empty = launch(arguments: [])
        XCTAssertTrue(empty.staticTexts["오늘의 던전이 비었습니다"].waitForExistence(timeout: 4))
        snapshot("06-empty-dungeon", timeWaitingForIdle: 0)
        empty.terminate()
    }

    @MainActor
    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += uiTestKoreanLocaleArguments
        app.launchArguments += ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launchArguments += arguments
        app.launch()
        return app
    }
}
