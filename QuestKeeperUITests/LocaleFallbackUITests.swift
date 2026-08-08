import XCTest

/// Verifies the fallback locale for a device language QuestKeeper does not localize (Japanese):
/// the app must fall back to English, not to Korean (`developmentRegion`/`sourceLanguage`).
@MainActor
final class LocaleFallbackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testJapaneseDeviceLanguageFallsBackToEnglish() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launchArguments += ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Today's dungeon is empty"].waitForExistence(timeout: 4),
            "Japanese device language should fall back to English, not Korean."
        )
        XCTAssertFalse(app.staticTexts["오늘의 던전이 비었습니다"].exists)
    }
}
