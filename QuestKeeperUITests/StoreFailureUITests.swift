import XCTest

/// Covers the in-memory fallback the app takes when its on-disk store will not open.
///
/// The property under test is that the app **launches** instead of crashing, and says so. No unit
/// test can read that: `QuestKeeperApp.init` is where the decision lives, and the banner is only
/// reachable through a real launch. `-uiTestingStoreFailure` throws inside the same `do` block the
/// real failure lands in, so this exercises the actual catch → fallback → banner path rather than
/// setting the flag and asserting a view it never had to derive.
@MainActor
final class StoreFailureUITests: XCTestCase {
    private let bannerIdentifier = "storeFailureBanner"
    private let bannerTitle = "저장소를 열지 못했습니다"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFallbackLaunchesTheBoardAndWarnsTheUser() {
        let app = storeFailureApp()
        app.launch()

        let banner = app.descendants(matching: .any)[bannerIdentifier]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        // The identifier alone would pass on an empty banner, and a gate that only checks a key has
        // a value is exactly what let four English defects ship. Read the words.
        XCTAssertTrue(
            banner.label.contains(bannerTitle),
            "배너가 실패 사유를 말하지 않습니다: \(banner.label)"
        )
        XCTAssertTrue(
            banner.label.contains("저장되지 않습니다"),
            "배너가 저장되지 않는다는 사실을 말하지 않습니다: \(banner.label)"
        )

        // The point of the fallback is a usable app, not merely a process that survived launch.
        XCTAssertTrue(app.buttons["questAddButton"].exists)
        XCTAssertTrue(app.staticTexts["dungeonEmptyTitle"].exists)
    }

    /// The container swap on foreground must not run while the app is on a fallback. Without the
    /// guard it reopens the on-disk store the moment its problem clears and replaces the container,
    /// so everything made during the fallback session disappears on the next foreground.
    ///
    /// Asserting the banner alone would prove nothing here — it is derived from a launch-time `let`,
    /// so it survives whether or not the guard exists. The quest is the load-bearing assertion:
    /// remove `!storeFailedToOpen` from the swap branch and this is the test that goes red.
    func testFallbackKeepsThisSessionsQuestAcrossBackgrounding() {
        let app = storeFailureApp()
        app.launch()

        let banner = app.descendants(matching: .any)[bannerIdentifier]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))

        let title = "폴백 세션 퀘스트"
        createQuest(title: title, in: app)

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(
            app.staticTexts[title].waitForExistence(timeout: 5),
            "포그라운드 복귀가 폴백 컨테이너를 교체해 이 세션의 퀘스트를 버렸습니다."
        )
        XCTAssertTrue(banner.exists)
    }

    /// Negative control. Without it the assertions above would pass against a banner that is always
    /// on screen, which asserts nothing about the failure path.
    func testHealthyStoreShowsNoBanner() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = uiTestKoreanLocaleArguments + [
            "-uiTestingInMemoryStore",
            "-onboardingVariant", "control",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["dungeonEmptyTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)[bannerIdentifier].exists)
    }

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

    private func storeFailureApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // `-onboardingVariant control` like every other UI test here: the fallback store is empty,
        // so the app enrols in the onboarding experiment with a *random* variant, and drawing
        // `guided` replaces the empty board with the onboarding card. Without the pin these
        // assertions are a coin flip.
        app.launchArguments = uiTestKoreanLocaleArguments + [
            "-uiTestingStoreFailure",
            "-onboardingVariant", "control",
        ]
        return app
    }
}
