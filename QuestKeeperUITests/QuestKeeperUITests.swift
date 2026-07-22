//
//  QuestKeeperUITests.swift
//  QuestKeeperUITests
//
//  Created by Dongmin yu on 7/8/26.
//

import XCTest

final class QuestKeeperUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testSwipeRightThenTapCompleteRemovesQuest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemoryStore", "-onboardingVariant", "control"]
        app.launch()

        app.buttons["전투 추가"].firstMatch.tap()
        let titleField = app.textFields["제목"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Swipe completion UI test")
        app.buttons["저장"].tap()

        let questTitle = app.staticTexts["Swipe completion UI test"]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 3))

        questTitle.swipeRight()

        let completeButton = app.buttons["완료"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 1))
        completeButton.tap()

        XCTAssertTrue(questTitle.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
