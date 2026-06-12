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
        XCTAssertTrue(app.buttons["Share day"].exists)
        let stepsLeftText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'steps left'")).firstMatch
        XCTAssertTrue(stepsLeftText.waitForExistence(timeout: 3))

        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.buttons["Goal Hit"].waitForExistence(timeout: 3))
        app.buttons["Goal Hit"].tap()
        XCTAssertTrue(app.buttons["Workouts"].exists)

        app.tabBars.buttons["Compete"].tap()
        XCTAssertTrue(app.staticTexts["Household Board"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Your board name"].exists)
        XCTAssertTrue(app.buttons["Generate"].exists)
        XCTAssertTrue(app.buttons["Sync"].exists)
        XCTAssertTrue(app.buttons["Copy"].exists)
        XCTAssertTrue(app.buttons["Paste"].exists)
        XCTAssertTrue(app.buttons["Join from Clipboard"].exists)
        XCTAssertTrue(app.staticTexts["Leaderboard"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add Check-In"].waitForExistence(timeout: 3))
        app.buttons["Add Check-In"].tap()
        XCTAssertTrue(app.navigationBars["Check-In"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["STEP RECEIPT"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Display name"].exists)
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Dark"].exists)

        let privacyCopy = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'opt-in household competition totals'"))
            .firstMatch
        if !privacyCopy.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(privacyCopy.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSampleWorkoutDetailShowsRichPanels() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-stepReceiptUITestingResetDefaults"]
        app.launch()

        if app.staticTexts["StepReceipt"].waitForExistence(timeout: 5) {
            app.buttons["Preview Sample Data"].tap()
        }

        XCTAssertTrue(app.staticTexts["Hourly Steps"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Activity"].tap()
        let workoutsSegment = app.segmentedControls.buttons["Workouts"]
        XCTAssertTrue(workoutsSegment.waitForExistence(timeout: 3))
        workoutsSegment.tap()

        for filter in ["All", "Stairs", "Strength", "Outdoor Walk", "Indoor Walk", "Other"] {
            XCTAssertTrue(app.buttons[filter].waitForExistence(timeout: 3), "Missing workout filter \(filter)")
        }

        app.buttons["Strength"].tap()
        let strengthRow = workoutRow(containing: "Traditional Strength Training", in: app).firstMatch
        XCTAssertTrue(strengthRow.waitForExistence(timeout: 3))

        app.buttons["Outdoor Walk"].tap()
        let outdoorWalkRow = workoutRow(containing: "Outdoor Walk", in: app)
            .firstMatch
        scrollToElement(outdoorWalkRow, in: app)
        XCTAssertTrue(outdoorWalkRow.waitForExistence(timeout: 3))
        outdoorWalkRow.tap()

        XCTAssertTrue(app.navigationBars["Outdoor Walk"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Share workout"].exists)
        XCTAssertTrue(app.staticTexts["Workout Snapshot"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Workout Tag"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Push Day"].exists)
        app.buttons["Push Day"].tap()
        XCTAssertTrue(app.staticTexts["Push Day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Additional Info"].exists)
        XCTAssertTrue(app.staticTexts["Workout Receipt"].exists)
        XCTAssertTrue(app.staticTexts["Pace"].exists)
        XCTAssertTrue(app.staticTexts["Weather"].exists)
        XCTAssertTrue(app.staticTexts["Heart Rate"].exists)
        XCTAssertTrue(app.staticTexts["Average"].exists)
        XCTAssertTrue(app.staticTexts["Max"].exists)
        XCTAssertTrue(app.staticTexts["Zone 1"].exists)
        XCTAssertTrue(app.staticTexts["Zone 5"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let taggedRow = workoutRow(containing: "Push Day", in: app).firstMatch
        XCTAssertTrue(taggedRow.waitForExistence(timeout: 3))
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
    }

    private func workoutRow(containing text: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "workout-row-", text)
        )
    }
}
