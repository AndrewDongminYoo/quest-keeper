import XCTest

/// 스펙 023이 요구하는 세 가지 UI 확인: 첫 퀘스트 게이트, 설정 컨트롤, 권한 거부 경로.
///
/// 설정은 `UserDefaults.standard`에 저장되어 앱 재실행 사이에 살아남는다.
/// 그래서 각 테스트는 자기 시작 상태를 스스로 세우거나 절대값 대신 변화를 검증한다.
@MainActor
final class ReengagementReminderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 첫 퀘스트를 저장하기 전에는 알림을 켤 수 없고, 하나 저장하면 켤 수 있게 된다.
    /// 게이트는 저장된 설정이 아니라 현재 퀘스트 존재 여부에서 나오므로 앞선 테스트의 저장값과 무관하다.
    func testEnablingStaysGatedUntilAFirstQuestExists() {
        let app = launch(arguments: uiTestKoreanLocaleArguments)

        openSettings(in: app)
        let gated = app.switches["reengagementReminderEnabledToggle"]
        XCTAssertTrue(gated.waitForExistence(timeout: 3))
        XCTAssertFalse(gated.isEnabled)
        XCTAssertTrue(app.staticTexts["첫 퀘스트를 저장하면 알림을 켤 수 있어요."].exists)
        app.buttons["취소"].tap()

        createQuest(title: "빨래", in: app)

        openSettings(in: app)
        let unlocked = app.switches["reengagementReminderEnabledToggle"]
        XCTAssertTrue(unlocked.waitForExistence(timeout: 3))
        XCTAssertTrue(unlocked.isEnabled)
    }

    /// 퀘스트가 하나도 없어도 기록된 생성 사실이 있으면 첫 가치 경계는 열린 채다.
    /// 게이트가 현재 퀘스트 수를 읽던 시절에는 이 테스트가 실패한다.
    func testGateStaysOpenWithoutAnyQuestWhenACreationFactExists() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + ["-uiTestingCreationFactWithoutQuest"])

        openSettings(in: app)
        let toggle = app.switches["reengagementReminderEnabledToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertTrue(toggle.isEnabled, "퀘스트가 없어도 기록된 생성 사실이 있으면 경계는 열려 있어야 한다")
    }

    /// 시각, 반복, 방해 금지 시간, 목적 컨트롤이 모두 노출되고, 저장한 변경이 다시 열었을 때 남아 있다.
    func testScheduleControlsAreExposedAndSurviveASave() {
        let app = launch(arguments: uiTestKoreanLocaleArguments)
        createQuest(title: "빨래", in: app)

        openSettings(in: app)
        XCTAssertTrue(app.staticTexts["알림 시각"].exists)
        XCTAssertTrue(app.staticTexts["반복"].exists)
        XCTAssertTrue(app.staticTexts["목적"].exists)
        XCTAssertTrue(quietHoursToggle(in: app).exists)

        let toggle = app.switches["reengagementReminderEnabledToggle"]
        XCTAssertTrue(toggle.isEnabled)
        let before = toggle.value as? String
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let after = toggle.value as? String
        XCTAssertNotEqual(before, after, "토글이 실제로 뒤집히지 않았다")

        app.buttons["reengagementReminderSaveButton"].tap()

        openSettings(in: app)
        let reopened = app.switches["reengagementReminderEnabledToggle"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 3))
        XCTAssertEqual(reopened.value as? String, after, "저장한 값이 다시 열었을 때 남지 않았다")
    }

    /// 권한이 거부된 상태에서는 설명과 시스템 설정 경로가 나타난다.
    /// 거부 상태는 `QuestNotificationCenter` 심(seam)에서만 주입되므로 서비스, 보드, 시트는 실제 코드가 돈다.
    func testDeniedPermissionOffersTheSystemSettingsRoute() {
        let app = launch(arguments: uiTestKoreanLocaleArguments + ["-uiTestingNotificationDenied"])

        openSettings(in: app)
        let explanation = app.staticTexts["알림을 받으려면 시스템 설정에서 알림을 켜세요."]
        if !explanation.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(explanation.waitForExistence(timeout: 3))
        // `Form` renders lazily, so a row below the fold is absent from the tree rather than merely
        // off-screen. Scrolling for the explanation alone is not enough: it sits above the button,
        // so it is found while the button — the only route to system settings from here — is not.
        let openSettings = app.buttons["설정 열기"]
        if !openSettings.exists {
            app.swipeUp()
        }
        XCTAssertTrue(openSettings.waitForExistence(timeout: 3))
    }

    private func openSettings(in app: XCUIApplication) {
        let entry = app.buttons["reengagementReminderSettingsButton"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()
        XCTAssertTrue(app.navigationBars["재방문 알림"].waitForExistence(timeout: 3))
    }

    private func quietHoursToggle(in app: XCUIApplication) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "방해 금지 시간 사용")).firstMatch
    }

    private func createQuest(title: String, in app: XCUIApplication) {
        let addButton = app.buttons["questAddButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let titleField = app.textFields["제목"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText(title)

        let saveButton = app.buttons["questEditorSaveButton"]
        saveButton.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3))
        // 에디터 시트가 닫히는 중에 다음 시트를 열면 SwiftUI가 그 표시를 조용히 무시한다.
        // 보드에 행이 보이는 것만으로는 시트가 사라졌다는 뜻이 아니므로 닫힘을 따로 기다린다.
        XCTAssertTrue(saveButton.waitForNonExistence(timeout: 3))
    }

    private func launch(arguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launch()
        return app
    }
}
