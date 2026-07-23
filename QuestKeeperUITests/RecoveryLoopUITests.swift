import XCTest

@MainActor
final class RecoveryLoopUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSingleQuestConfirmsOneFocus() {
        let app = recoveryApp(variant: "singleQuest")
        app.launch()

        XCTAssertTrue(app.staticTexts["다시 와서 반가워요"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["회복 퀘스트 1"].exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "실패")
        ).firstMatch.exists)
        app.buttons["이 퀘스트로 다시 시작"].tap()

        XCTAssertTrue(app.staticTexts["오늘의 핵심 퀘스트"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0/1 완료"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["승리 1"].exists)
    }

    func testChooseTodayRequiresExplicitSelection() {
        let app = recoveryApp(variant: "chooseToday")
        app.launch()

        XCTAssertTrue(app.buttons["오늘 다시 고르기"].waitForExistence(timeout: 3))
        app.buttons["오늘 다시 고르기"].tap()
        XCTAssertTrue(app.buttons["오늘 이대로 시작 (2/3)"].waitForExistence(timeout: 2))
        app.buttons["오늘 이대로 시작 (2/3)"].tap()

        XCTAssertTrue(app.staticTexts["0/2 완료"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["다시 와서 반가워요"].exists)
    }

    func testChooseTodayCancellationPreservesOffer() {
        let app = recoveryApp(variant: "chooseToday")
        app.launch()

        XCTAssertTrue(app.buttons["오늘 다시 고르기"].waitForExistence(timeout: 3))
        app.buttons["오늘 다시 고르기"].tap()
        XCTAssertTrue(app.buttons["취소"].waitForExistence(timeout: 2))
        app.buttons["취소"].tap()

        XCTAssertTrue(app.buttons["오늘 다시 고르기"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["다시 와서 반가워요"].exists)
    }

    func testDismissalReturnsToOrdinaryBoardWithoutReplay() {
        let app = recoveryApp(variant: "singleQuest")
        app.launch()
        app.buttons["지금은 괜찮아요"].tap()

        XCTAssertFalse(app.staticTexts["다시 와서 반가워요"].exists)
        XCTAssertTrue(app.staticTexts["회복 퀘스트 1"].exists)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertFalse(app.staticTexts["다시 와서 반가워요"].exists)
    }

    func testNoPendingCreationCancellationPreservesOffer() {
        let app = recoveryApp(variant: "singleQuest")
        app.launchArguments.append("-uiTestingRecoveryNoPending")
        app.launch()

        XCTAssertTrue(app.buttons["작은 퀘스트 만들기"].waitForExistence(timeout: 3))
        app.buttons["작은 퀘스트 만들기"].tap()
        XCTAssertTrue(app.navigationBars["새 퀘스트"].waitForExistence(timeout: 2))
        app.buttons["취소"].tap()
        XCTAssertTrue(app.buttons["작은 퀘스트 만들기"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["오늘의 핵심 퀘스트"].exists)
    }

    func testNoPendingCreationDoesNotAutoConfirmFocus() {
        let app = recoveryApp(variant: "singleQuest")
        app.launchArguments.append("-uiTestingRecoveryNoPending")
        app.launch()

        XCTAssertTrue(app.buttons["작은 퀘스트 만들기"].waitForExistence(timeout: 3))
        app.buttons["작은 퀘스트 만들기"].tap()
        XCTAssertTrue(app.navigationBars["새 퀘스트"].waitForExistence(timeout: 2))
        app.buttons["저장"].tap()

        XCTAssertTrue(app.staticTexts["물 한 잔 마시기"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["오늘 이대로 시작"].exists)
        XCTAssertFalse(app.staticTexts["0/1 완료"].exists)
    }

    func testPersistenceFailureKeepsCardAndExplainsConflict() {
        let app = recoveryApp(variant: "singleQuest")
        app.launchArguments.append("-uiTestingRecoveryPersistenceFailure")
        app.launch()
        app.buttons["이 퀘스트로 다시 시작"].tap()

        XCTAssertTrue(app.alerts["선택을 다시 확인해주세요"].waitForExistence(timeout: 2))
        app.alerts.buttons["확인"].tap()
        XCTAssertTrue(app.staticTexts["다시 와서 반가워요"].exists)
    }

    func testAccessibilityOrderAtLargestDynamicType() {
        let app = recoveryApp(variant: "singleQuest")
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let title = app.staticTexts["다시 와서 반가워요"]
        let description = app.staticTexts[
            "쉬었다 와도 괜찮아요. 오늘 할 일부터 가볍게 시작해볼까요?"
        ]
        let primary = app.buttons["이 퀘스트로 다시 시작"]
        let dismiss = app.buttons["지금은 괜찮아요"]

        for element in [title, description, primary, dismiss] {
            XCTAssertTrue(element.waitForExistence(timeout: 3))
        }
        guard let quest = app.staticTexts.matching(
            identifier: "회복 퀘스트 1"
        ).allElementsBoundByIndex.first(where: {
            $0.frame.minY > description.frame.maxY
                && $0.frame.minY < primary.frame.minY
        }) else {
            XCTFail("회복 카드의 추천 퀘스트가 접근성 순서에 없습니다.")
            return
        }
        XCTAssertLessThan(title.frame.minY, description.frame.minY)
        XCTAssertLessThan(description.frame.minY, quest.frame.minY)
        XCTAssertLessThan(quest.frame.minY, primary.frame.minY)
        XCTAssertLessThan(primary.frame.minY, dismiss.frame.minY)
        XCTAssertGreaterThanOrEqual(primary.frame.height, 44)
        XCTAssertGreaterThanOrEqual(dismiss.frame.height, 44)
    }

    func testRemainsDormantWithoutBothDevelopmentGates() {
        XCUIDevice.shared.orientation = .portrait
        let missingVariant = XCUIApplication()
        missingVariant.launchArguments = [
            "-uiTestingInMemoryStore",
            "-uiTestingRecoveryFixture",
            "-dailyFocusLoopEnabled",
        ]
        missingVariant.launch()
        assertRecoveryIsDormant(in: missingVariant)
        missingVariant.terminate()

        let missingDailyFocus = XCUIApplication()
        missingDailyFocus.launchArguments = [
            "-uiTestingInMemoryStore",
            "-uiTestingRecoveryFixture",
            "-recoveryLoopVariant", "singleQuest",
        ]
        missingDailyFocus.launch()
        assertRecoveryIsDormant(in: missingDailyFocus)
    }

    private func recoveryApp(variant: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingInMemoryStore",
            "-uiTestingRecoveryFixture",
            "-dailyFocusLoopEnabled",
            "-recoveryLoopVariant", variant,
        ]
        return app
    }

    private func assertRecoveryIsDormant(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["회복 퀘스트 1"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["다시 와서 반가워요"].exists)
        XCTAssertFalse(app.buttons["이 퀘스트로 다시 시작"].exists)
        XCTAssertFalse(app.buttons["오늘 다시 고르기"].exists)
    }
}
