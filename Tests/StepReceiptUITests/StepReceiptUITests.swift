import XCTest

final class StepReceiptUITests: XCTestCase {
    @MainActor
    func testDayFlowCardShowsPeakAndQuietHoursToggle() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        let dayFlow = app.otherElements["today-day-flow"]
        XCTAssertTrue(scrollToElement(dayFlow, in: app, timeout: 5, maxSwipes: 4))

        let peakPill = app.descendants(matching: .any)["day-flow-peak-pill"]
        XCTAssertTrue(peakPill.waitForExistence(timeout: 3))

        let quietHoursToggle = app.buttons["day-flow-quiet-hours-toggle"]
        if quietHoursToggle.waitForExistence(timeout: 2) {
            quietHoursToggle.tap()
            XCTAssertTrue(app.staticTexts["Hide quiet hours"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["Hour"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["Steps"].waitForExistence(timeout: 2))
            quietHoursToggle.tap()
        }
    }

    @MainActor
    func testActivityWorkoutStatsToggleShowsRowStats() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        app.tabBars.buttons["Activity"].tap()
        let modePicker = app.segmentedControls["activity-history-mode-picker"]
        XCTAssertTrue(modePicker.buttons["Workouts"].waitForExistence(timeout: 3))
        modePicker.buttons["Workouts"].tap()

        let statsToggle = app.buttons["activity-workout-stats-toggle"]
        XCTAssertTrue(statsToggle.waitForExistence(timeout: 3))
        XCTAssertFalse(statsToggle.isSelected)

        let firstWorkoutRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout-row-'")).firstMatch
        XCTAssertTrue(firstWorkoutRow.waitForExistence(timeout: 3))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout-row-stats-line-'")).count,
            0
        )

        statsToggle.tap()
        XCTAssertTrue(statsToggle.isSelected)
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout-row-stats-line-'")).firstMatch
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'kcal/min'")).firstMatch.exists)

        statsToggle.tap()
        XCTAssertFalse(statsToggle.isSelected)
    }

    @MainActor
    func testDayFlowPatternDrillInOpensSheet() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        let dayFlow = app.otherElements["today-day-flow"]
        XCTAssertTrue(scrollToElement(dayFlow, in: app, timeout: 5, maxSwipes: 4))

        let patternButton = app.buttons["day-flow-pattern-button"]
        XCTAssertTrue(patternButton.waitForExistence(timeout: 3))
        patternButton.tap()

        XCTAssertTrue(app.otherElements["day-flow-pattern-sheet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["day-flow-pattern-scope-picker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["day-flow-pattern-heatmap"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["day-flow-pattern-hour-profile"].waitForExistence(timeout: 3))

        app.buttons["Done"].tap()
        XCTAssertTrue(dayFlow.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSamplePreviewShowsCoreTabs() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        let weatherStrip = app.otherElements["today-weather-strip"]
        XCTAssertTrue(weatherStrip.waitForExistence(timeout: 3))
        weatherStrip.tap()
        XCTAssertTrue(app.otherElements["today-weather-detail"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(weatherStrip.waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["today-day-flow"].waitForExistence(timeout: 3) || app.staticTexts["Day Flow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["today-hero-coach"].waitForExistence(timeout: 3) || app.staticTexts.matching(NSPredicate(format: "label == 'Coach'")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Share day"].exists)
        let stepsLeftText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'left to'")).firstMatch
        XCTAssertTrue(stepsLeftText.waitForExistence(timeout: 3))
        let stepsHeadline = app.staticTexts.matching(
            NSPredicate(format: "label ENDSWITH 'steps' AND NOT label CONTAINS '...'")
        ).firstMatch
        XCTAssertTrue(stepsHeadline.waitForExistence(timeout: 3))
        XCTAssertTrue(scrollToElement(app.otherElements["today-quick-digest"], in: app, timeout: 5, maxSwipes: 6))

        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.buttons["Goal Hit"].waitForExistence(timeout: 3))
        app.buttons["Goal Hit"].tap()
        XCTAssertTrue(app.buttons["Workouts"].exists)

        app.tabBars.buttons["Compete"].tap()
        let competeLoaded = app.otherElements["compete-welcome-screen"].waitForExistence(timeout: 5)
            || app.otherElements["compete-leaderboard"].waitForExistence(timeout: 3)
        XCTAssertTrue(competeLoaded)
        let startBoardButton = app.buttons["compete-welcome-start"].exists
            ? app.buttons["compete-welcome-start"]
            : app.buttons["Start a household board"]
        if startBoardButton.waitForExistence(timeout: 3) {
            startBoardButton.tap()
            XCTAssertTrue(app.navigationBars["Start Board"].waitForExistence(timeout: 3))
            app.buttons["Close"].tap()
        }

        if app.otherElements["compete-welcome-screen"].waitForExistence(timeout: 2) {
            XCTAssertTrue(app.otherElements["compete-welcome-quick-join"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.textFields["compete-welcome-join-code"].exists)
            XCTAssertTrue(app.textFields["compete-welcome-join-name"].exists)
            XCTAssertTrue(app.buttons["compete-welcome-join-submit"].exists)
        }

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
        XCTAssertTrue(app.buttons["insights-cardio-card"].waitForExistence(timeout: 3))
        XCTAssertTrue(scrollToElement(app.buttons["insights-strength-card"], in: app, timeout: 3, maxSwipes: 2))

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
    func testCompeteJoinConfirmationSheetFromLaunchArg() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-stepReceiptUITestingResetDefaults",
            "-stepReceiptUITestingUseSampleData",
            "-CompeteJoinCode",
            "SRTEST123"
        ]
        app.launch()

        if app.buttons["Preview Sample Data"].waitForExistence(timeout: 2) {
            app.buttons["Preview Sample Data"].tap()
        }

        app.tabBars.buttons["Compete"].tap()
        XCTAssertTrue(app.otherElements["compete-join-confirmation-sheet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["compete-join-confirm-name"].exists)
        XCTAssertTrue(app.buttons["compete-join-confirm-submit"].exists)
    }

    @MainActor
    func testCompeteWelcomeQuickJoinFields() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        app.tabBars.buttons["Compete"].tap()
        XCTAssertTrue(app.otherElements["compete-welcome-screen"].waitForExistence(timeout: 5))

        let codeField = app.textFields["compete-welcome-join-code"]
        let nameField = app.textFields["compete-welcome-join-name"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 3))
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))

        codeField.tap()
        codeField.typeText("SRTEST2026")
        nameField.tap()
        nameField.typeText("Partner")

        XCTAssertTrue(app.buttons["compete-welcome-join-submit"].isEnabled)
        XCTAssertTrue(app.buttons["compete-welcome-join"].exists)
    }

    @MainActor
    func testSampleWorkoutDetailShowsRichPanels() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchWithSampleData(app)

        XCTAssertTrue(scrollToElement(app.otherElements["today-day-flow"], in: app, timeout: 5, maxSwipes: 2) || app.staticTexts["Day Flow"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(scrollToElement(app.staticTexts["Pace"], in: app, timeout: 3, maxSwipes: 4))
        XCTAssertTrue(scrollToElement(app.staticTexts["Weather"], in: app, timeout: 2, maxSwipes: 2))
        XCTAssertTrue(scrollToElement(app.staticTexts["Heart Rate"], in: app, timeout: 2, maxSwipes: 2))
        XCTAssertTrue(app.staticTexts["Average"].exists)
        XCTAssertTrue(scrollToElement(app.staticTexts["Min"], in: app, timeout: 2, maxSwipes: 2))
        XCTAssertTrue(app.staticTexts["Max"].exists)
        XCTAssertTrue(scrollToElement(app.staticTexts["Zone 1"], in: app, timeout: 2, maxSwipes: 2))
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
        let movementScope = app.buttons["cardio-detail-scope-movement"]
        XCTAssertTrue(scrollToElement(movementScope, in: app, timeout: 2, maxSwipes: 2))
        movementScope.tap()
        let includeStairsScope = app.buttons["cardio-detail-scope-includeStairs"]
        XCTAssertTrue(includeStairsScope.waitForExistence(timeout: 2))
        includeStairsScope.tap()
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
