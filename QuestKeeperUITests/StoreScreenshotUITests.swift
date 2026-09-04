import XCTest

/// 스토어 스크린샷은 로캘마다 한 번씩 돌기 때문에 (`Snapfile`의 `languages`), 다른 UI 스위트와 달리
/// 로케일을 한국어로 못박지 않는다. snapshot이 주입하는 `-AppleLanguages`가 언어를 정하고,
/// 화면 판별은 번역되지 않는 `accessibilityIdentifier`로 한다.
final class StoreScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStoreScreenshots() throws {
        XCUIDevice.shared.orientation = .portrait

        let populated = launch(arguments: ["-storeScreenshotFixture"])
        XCTAssertTrue(populated.staticTexts["questRowTitle"].firstMatch.waitForExistence(timeout: 8))
        snapshot("01-dungeon", timeWaitingForIdle: 0)
        populated.buttons["heroAppearanceButton"].firstMatch.tap()
        XCTAssertTrue(populated.buttons["heroAppearanceDoneButton"].waitForExistence(timeout: 8))
        snapshot("03-hero-appearance", timeWaitingForIdle: 0)
        populated.terminate()

        // 전투 단계는 고정해 두고 캡처한다. 실제 연출은 0.42초 만에 지나가 잡을 수 없다.
        let battle = launch(arguments: ["-storeScreenshotFixture", "-storeScreenshotBattle"])
        XCTAssertTrue(battle.staticTexts["questRowTitle"].firstMatch.waitForExistence(timeout: 8))
        snapshot("02-battle", timeWaitingForIdle: 0)
        battle.terminate()

        let grave = launch(arguments: ["-storeScreenshotFixture", "-uiTestingDailyFocusGrave"])
        // 섹션 제목은 children: .combine으로 합쳐져 요소 타입이 정해지지 않는다.
        let graveSectionTitle = grave.descendants(matching: .any)["graveSectionTitle"]
        XCTAssertTrue(graveSectionTitle.waitForExistence(timeout: 8))
        snapshot("06-daily-grave", timeWaitingForIdle: 0)
        grave.terminate()

        let editor = launch(arguments: [])
        let addButton = editor.buttons["questAddButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 8))
        addButton.tap()
        XCTAssertTrue(editor.buttons["questEditorSaveButton"].waitForExistence(timeout: 8))
        snapshot("07-quest-editor", timeWaitingForIdle: 0)
        editor.terminate()

        let empty = launch(arguments: [])
        XCTAssertTrue(empty.staticTexts["dungeonEmptyTitle"].waitForExistence(timeout: 8))
        snapshot("08-empty-dungeon", timeWaitingForIdle: 0)
        empty.terminate()
    }

    @MainActor
    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launchArguments += arguments
        app.launch()
        return app
    }
}
