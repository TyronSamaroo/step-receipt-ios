import XCTest

final class StepReceiptUITests: XCTestCase {
    @MainActor
    func testSamplePreviewShowsCoreTabs() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-stepReceiptUITestingResetDefaults"]
        app.launch()

        if app.staticTexts["StepReceipt"].waitForExistence(timeout: 5) {
            app.buttons["Preview Sample Data"].tap()
        }

        XCTAssertTrue(app.staticTexts["Hourly Steps"].waitForExistence(timeout: 5))
        let stepsLeftText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'steps left'")).firstMatch
        XCTAssertTrue(stepsLeftText.waitForExistence(timeout: 3))

        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.buttons["Goal Hit"].waitForExistence(timeout: 3))
        app.buttons["Goal Hit"].tap()
        XCTAssertTrue(app.buttons["Workouts"].exists)

        app.tabBars.buttons["Compete"].tap()
        XCTAssertTrue(app.staticTexts["Leaderboard"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["STEP RECEIPT"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Display name"].exists)

        let privacyCopy = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'syncs only aggregate daily summary records'"))
            .firstMatch
        if !privacyCopy.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(privacyCopy.waitForExistence(timeout: 3))
    }
}
