import XCTest

final class StepReceiptUITests: XCTestCase {
    @MainActor
    func testSamplePreviewShowsCoreTabs() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        XCTAssertTrue(scrollToElement(app.staticTexts["Hourly Steps"], in: app, timeout: 5, maxSwipes: 2))
        XCTAssertTrue(app.buttons["today-quick-digest"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Today Coach"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.buttons["Share Code"].exists)
        XCTAssertTrue(app.buttons["Copy Code"].exists)
        XCTAssertTrue(app.buttons["Paste Code"].exists)
        XCTAssertTrue(app.buttons["Join"].exists)
        XCTAssertTrue(app.otherElements["compete-sync-status-row"].exists || app.staticTexts["Sync Status"].exists)
        XCTAssertFalse(app.buttons["Send iCloud Invite"].exists)
        XCTAssertTrue(app.staticTexts["Leaderboard"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add Check-In"].waitForExistence(timeout: 3))
        app.buttons["Add Check-In"].tap()
        XCTAssertTrue(app.navigationBars["Check-In"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.buttons["Day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Week"].exists)
        XCTAssertTrue(app.buttons["Month"].exists)
        let periodLabel = app.staticTexts["insights-period-label"]
        XCTAssertTrue(periodLabel.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Previous period"].exists)
        XCTAssertTrue(app.buttons["Next period"].exists)
        XCTAssertFalse(app.buttons["Next period"].isEnabled)
        let currentPeriodLabel = periodLabel.label
        app.buttons["Previous period"].tap()
        XCTAssertTrue(waitForLabelChange(periodLabel, from: currentPeriodLabel, timeout: 3))
        XCTAssertTrue(app.staticTexts["WEEK RECEIPT"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Activity Heat Map"].exists)
        XCTAssertTrue(scrollToElement(app.staticTexts["Cardio"], in: app, timeout: 3, maxSwipes: 3))
        XCTAssertTrue(app.staticTexts["Best cardio"].exists)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Display name"].exists)
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Dark"].exists)
        XCTAssertTrue(scrollToElement(app.buttons["repair-health-sync-button"], in: app, timeout: 1, maxSwipes: 5))
        let liveActivitySwitch = app.switches["Lock Screen steps"]
        XCTAssertTrue(scrollToElement(liveActivitySwitch, in: app, timeout: 1, maxSwipes: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["Diagnostics"], in: app, timeout: 1, maxSwipes: 3))
        let copyDiagnostics = app.buttons["copy-diagnostics-button"]
        XCTAssertTrue(scrollToElement(copyDiagnostics, in: app, timeout: 1, maxSwipes: 2))
        copyDiagnostics.tap()
        XCTAssertTrue(app.buttons["Diagnostics copied"].waitForExistence(timeout: 3))

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
        launchWithSampleData(app)

        XCTAssertTrue(scrollToElement(app.staticTexts["Hourly Steps"], in: app, timeout: 5, maxSwipes: 2))
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
        XCTAssertTrue(app.staticTexts["Workout Template"].waitForExistence(timeout: 3))
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
    func testInsightsCardioAndWeekDetailDrillDown() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.buttons["Previous period"].waitForExistence(timeout: 3))
        app.buttons["Previous period"].tap()

        let cardioCard = app.buttons["insights-cardio-card"]
        XCTAssertTrue(scrollToElement(cardioCard, in: app, timeout: 3, maxSwipes: 4))
        cardioCard.tap()

        XCTAssertTrue(app.navigationBars["Cardio Detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Zone 1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Zone 5"].exists)
        XCTAssertTrue(app.buttons["edit-heart-rate-zones-button"].exists)
        app.buttons["edit-heart-rate-zones-button"].tap()

        XCTAssertTrue(app.navigationBars["Heart Rate Zones"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["heart-rate-zones-reset-defaults-button"].waitForExistence(timeout: 3))
        app.buttons["heart-rate-zones-reset-defaults-button"].tap()
        XCTAssertTrue(app.buttons["heart-rate-zones-save-button"].exists)
        app.buttons["heart-rate-zones-save-button"].tap()

        XCTAssertTrue(app.navigationBars["Cardio Detail"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 3))

        let dayRow = insightsDayRowWithWorkout(in: app).firstMatch
        XCTAssertTrue(scrollToElement(dayRow, in: app, timeout: 3, maxSwipes: 5))
        dayRow.tap()

        XCTAssertTrue(app.navigationBars["Day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Share day"].exists)
        XCTAssertTrue(app.staticTexts["Hourly Timeline"].waitForExistence(timeout: 3))

        let dayWorkout = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "day-workout-")
        ).firstMatch
        XCTAssertTrue(scrollToElement(dayWorkout, in: app, timeout: 3, maxSwipes: 3))
        dayWorkout.tap()

        XCTAssertTrue(app.staticTexts["Workout Snapshot"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Heart Rate"].exists)
    }

    @MainActor
    func testViewChoicesPersistAfterRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        app.tabBars.buttons["Activity"].tap()
        let modePicker = app.segmentedControls["activity-history-mode-picker"]
        XCTAssertTrue(modePicker.buttons["Workouts"].waitForExistence(timeout: 3))
        modePicker.buttons["Workouts"].tap()
        XCTAssertTrue(app.buttons["activity-workout-filter-outdoorWalk"].waitForExistence(timeout: 3))
        app.buttons["activity-workout-filter-outdoorWalk"].tap()

        app.tabBars.buttons["Insights"].tap()
        let scopePicker = app.segmentedControls["insights-scope-picker"]
        XCTAssertTrue(scopePicker.buttons["Month"].waitForExistence(timeout: 3))
        scopePicker.buttons["Month"].tap()

        app.terminate()
        launchWithSampleData(app, resetDefaults: false)

        app.tabBars.buttons["Activity"].tap()
        let restoredModePicker = app.segmentedControls["activity-history-mode-picker"]
        XCTAssertTrue(restoredModePicker.buttons["Workouts"].waitForExistence(timeout: 3))
        XCTAssertTrue(restoredModePicker.buttons["Workouts"].isSelected)
        let restoredOutdoorFilter = app.buttons["activity-workout-filter-outdoorWalk"]
        XCTAssertTrue(restoredOutdoorFilter.waitForExistence(timeout: 3))
        XCTAssertTrue(restoredOutdoorFilter.isSelected)

        app.tabBars.buttons["Insights"].tap()
        let restoredScopePicker = app.segmentedControls["insights-scope-picker"]
        XCTAssertTrue(restoredScopePicker.buttons["Month"].waitForExistence(timeout: 3))
        XCTAssertTrue(restoredScopePicker.buttons["Month"].isSelected)
    }

    @MainActor
    private func launchWithSampleData(_ app: XCUIApplication, resetDefaults: Bool = true) {
        app.launchArguments = resetDefaults
            ? ["-stepReceiptUITestingResetDefaults", "-stepReceiptUITestingUseSampleData"]
            : ["-stepReceiptUITestingUseSampleData"]
        app.launch()

        if app.buttons["Preview Sample Data"].waitForExistence(timeout: 2) {
            app.buttons["Preview Sample Data"].tap()
        }
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
    }

    @MainActor
    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval,
        maxSwipes: Int
    ) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }

    @MainActor
    private func waitForLabelChange(_ element: XCUIElement, from originalLabel: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label != %@", originalLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func workoutRow(containing text: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "workout-row-", text)
        )
    }

    @MainActor
    private func insightsDayRowWithWorkout(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label MATCHES %@",
                "insights-week-day-row-",
                ".*[1-9][0-9]* workouts.*"
            )
        )
    }
}
