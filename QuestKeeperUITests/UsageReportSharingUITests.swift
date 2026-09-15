import XCTest

@MainActor
final class UsageReportSharingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testReadyReportRequiresDisclosureBeforeSharing() {
        let app = launch(additionalArguments: ["-uiTestingUsageReportFixture"])

        openUsageReportDisclosure(in: app)

        XCTAssertTrue(app.otherElements["usageReportIntroCard"].exists)
        XCTAssertTrue(app.otherElements["usageReportIncludedCard"].exists)
        XCTAssertTrue(app.otherElements["usageReportExcludedCard"].exists)
        XCTAssertTrue(app.staticTexts["usageReportIncludedDescription"].exists)
        XCTAssertTrue(app.staticTexts["usageReportExcludedDescription"].exists)
        let shareAction = app.descendants(matching: .any)["usageReportShareButton"]
        app.swipeUp()
        XCTAssertTrue(shareAction.waitForExistence(timeout: 3))
        XCTAssertTrue(shareAction.isHittable)
    }

    func testUnavailableReportDoesNotOfferShareAction() {
        let app = launch(additionalArguments: ["-uiTestingUsageReportUnavailable"])

        openUsageReportDisclosure(in: app)

        XCTAssertTrue(app.staticTexts["usageReportUnavailableMessage"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["usageReportShareButton"].exists)
    }

    func testLargestDynamicTypeKeepsDisclosureScrollable() {
        let app = launch(additionalArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-uiTestingUsageReportFixture",
        ])

        openUsageReportDisclosure(in: app)

        let shareAction = app.descendants(matching: .any)["usageReportShareButton"]
        for _ in 0..<10 where !shareAction.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(shareAction.waitForExistence(timeout: 3))
        XCTAssertTrue(shareAction.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "ko-usage-report-accessibility-xxxl"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func openUsageReportDisclosure(in app: XCUIApplication) {
        let aboutButton = app.buttons["aboutButton"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 3))
        aboutButton.tap()

        let disclosureButton = app.buttons["usageReportDisclosureButton"]
        for _ in 0..<3 where !disclosureButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(disclosureButton.waitForExistence(timeout: 3))
        disclosureButton.tap()

        XCTAssertTrue(app.buttons["usageReportDisclosureDoneButton"].waitForExistence(timeout: 3))
    }

    private func launch(additionalArguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = uiTestKoreanLocaleArguments + [
            "-uiTestingInMemoryStore",
            "-onboardingVariant", "control",
        ] + additionalArguments
        app.launch()
        return app
    }
}
