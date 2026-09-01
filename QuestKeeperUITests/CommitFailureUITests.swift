import XCTest

/// Covers the banner shown after the store refuses a write.
///
/// No unit test in `QuestKeeperTests` can reach this: `ContentView.commitPendingChanges` is private
/// to a SwiftUI `View`, and nothing in that suite can make `ModelContext.save()` throw.
/// `-uiTestingRejectSaves` throws inside the same `do` block a real save failure lands in, so this
/// exercises the actual catch → rollback → banner path rather than setting the flag and asserting a
/// view it never had to derive — the same reasoning `StoreFailureUITests` is built on.
@MainActor
final class CommitFailureUITests: XCTestCase {
    private let bannerIdentifier = "commitFailureBanner"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testARejectedCompletionKeepsTheQuestAndSaysSo() {
        let app = rejectingApp()
        app.launch()

        let rows = app.staticTexts.matching(identifier: "questRowTitle")
        let firstRow = rows.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 8))
        let seededRowCount = rows.count
        XCTAssertGreaterThan(seededRowCount, 0, "픽스처가 퀘스트를 하나도 세우지 못했습니다")

        firstRow.swipeRight()
        // Every row carries its own swipe action, so the query is ambiguous on a seeded board.
        // The swiped row is the first one, and traversal order puts its button first.
        let completeButton = app.buttons["완료"].firstMatch
        XCTAssertTrue(completeButton.waitForExistence(timeout: 2))
        completeButton.tap()

        let banner = app.descendants(matching: .any)[bannerIdentifier]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        // The identifier alone would pass on an empty banner, which is how four English defects
        // shipped past their gates. Read the words.
        XCTAssertTrue(
            banner.label.contains("저장하지 못했습니다"),
            "배너가 저장 실패를 말하지 않습니다: \(banner.label)"
        )
        XCTAssertTrue(
            banner.label.contains("다시 시도"),
            "배너가 다음에 할 일을 말하지 않습니다: \(banner.label)"
        )

        // The banner's claim has to be true. On a successful completion this row leaves the board,
        // so an unchanged count is what distinguishes a rejected write from a taken one.
        XCTAssertEqual(rows.count, seededRowCount)
    }

    func testARejectedRoutineDeleteClosesTheSheetThatCoversTheBanner() {
        let app = rejectingApp(fixture: "-uiTestingRoutineFixture")
        app.launch()

        let manageButton = app.buttons["routineHomeManageButton"]
        XCTAssertTrue(manageButton.waitForExistence(timeout: 8))
        manageButton.tap()

        let manageSheet = app.navigationBars["루틴 관리"]
        XCTAssertTrue(manageSheet.waitForExistence(timeout: 3))

        let deleteButton = app.buttons["routineDelete-00000000-0000-0000-0000-000000000301"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        // The banner lives in the board's tree whether or not a sheet covers it, so asserting only
        // that it exists would pass on the very defect this test is here for. The sheet going away
        // is what makes the banner readable, so that is what gets asserted first.
        let sheetClosed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: manageSheet
        )
        wait(for: [sheetClosed], timeout: 5)

        let banner = app.descendants(matching: .any)[bannerIdentifier]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(
            banner.label.contains("저장하지 못했습니다"),
            "배너가 저장 실패를 말하지 않습니다: \(banner.label)"
        )

        // The refused delete was rolled back, so the rule is still there to manage.
        XCTAssertTrue(manageButton.waitForExistence(timeout: 3))
    }

    private func rejectingApp(fixture: String = "-storeScreenshotFixture") -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // `-onboardingVariant control` like every other UI test here: a random `guided` draw would
        // replace the board with the onboarding card and these assertions would be a coin flip.
        app.launchArguments = uiTestKoreanLocaleArguments + [
            "-uiTestingInMemoryStore",
            fixture,
            "-uiTestingRejectSaves",
            "-onboardingVariant", "control",
        ]
        return app
    }
}
