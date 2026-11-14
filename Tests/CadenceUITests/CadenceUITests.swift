import XCTest

final class CadenceUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testAppLaunchesWithMyDaySelected() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-empty"])

    waitForReadyState(in: app)
    XCTAssertTrue(app.navigationBars["My Day"].exists)
    XCTAssertEqual(primaryDestinations(in: app).count, 3)
    XCTAssertTrue(primaryDestination("My Day", in: app).isSelected)
  }

  @MainActor
  func testNavigatesAcrossAllPrimaryTabs() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-empty"])

    waitForReadyState(in: app)

    let myGoalsTab = primaryDestination("My Goals", in: app)
    XCTAssertTrue(myGoalsTab.exists)
    myGoalsTab.tap()
    XCTAssertTrue(element("my-goals-screen", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(myGoalsTab.isSelected)

    let historyTab = primaryDestination("History", in: app)
    historyTab.tap()
    XCTAssertTrue(element("history-screen", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(historyTab.isSelected)

    let myDayTab = primaryDestination("My Day", in: app)
    myDayTab.tap()
    XCTAssertTrue(app.navigationBars["My Day"].waitForExistence(timeout: 5))
    XCTAssertTrue(myDayTab.isSelected)
  }

  @MainActor
  func testEmptyHistoryShowsCurrentWeekAndZeroCountCategories() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-empty"])
    waitForReadyState(in: app)

    primaryDestination("History", in: app).tap()

    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["No Goals were planned for this week."].exists)
    XCTAssertTrue(app.staticTexts["0 this week"].firstMatch.exists)
    XCTAssertTrue(element("history-today-marker", in: app).exists)
    XCTAssertFalse(element("history-next-week", in: app).isEnabled)
    XCTAssertFalse(element("history-today", in: app).isEnabled)
  }

  @MainActor
  func testHistorySwitchesToMonthAndDrillsIntoACompleteWeek() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)
    primaryDestination("History", in: app).tap()
    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))

    app.buttons["Month"].tap()
    XCTAssertTrue(element("history-month-range", in: app).waitForExistence(timeout: 5))
    XCTAssertFalse(element("history-next-month", in: app).isEnabled)
    XCTAssertTrue(app.staticTexts["iIndulged this month"].exists)

    let week = element("history-month-week-2026-10-26", in: app)
    XCTAssertTrue(week.waitForExistence(timeout: 5))
    week.tap()
    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))
    element("history-day-2026-10-28", in: app).tap()
    XCTAssertTrue(element("history-day-ready", in: app).waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))
  }

  @MainActor
  func testPopulatedHistoryShowsNeutralWeeklyPlacementAndNavigation() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)
    primaryDestination("History", in: app).tap()

    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))
    let futureDay = element("history-day-2026-10-29", in: app)
    XCTAssertFalse(futureDay.isEnabled)
    XCTAssertTrue(futureDay.label.contains("not available yet"))
    XCTAssertTrue(
      app.descendants(matching: .any)
        .matching(NSPredicate(format: "label BEGINSWITH %@", "Walk, 1 of 5."))
        .firstMatch.exists)
    XCTAssertTrue(app.staticTexts["2 this week"].exists)
    XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "%")).count, 0)

    element("history-previous-week", in: app).tap()
    XCTAssertTrue(element("history-today", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(element("history-today", in: app).isEnabled)
    XCTAssertTrue(element("history-next-week", in: app).isEnabled)
    element("history-today", in: app).tap()
    XCTAssertTrue(element("history-today-marker", in: app).waitForExistence(timeout: 5))
  }

  @MainActor
  func testHistoryReadFailureOffersCalmRetry() throws {
    let app = launchApplication(arguments: ["--ui-test-history-read-failure"])
    waitForReadyState(in: app)
    primaryDestination("History", in: app).tap()

    XCTAssertTrue(app.staticTexts["History couldn’t be refreshed"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Try Again"].exists)
    XCTAssertFalse(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "SwiftData"))
        .firstMatch.exists)
  }

  @MainActor
  func testHistoryDayDetailIsReadOnlyAndReturnsToSelectedWeek() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)
    primaryDestination("History", in: app).tap()
    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))

    element("history-day-2026-10-28", in: app).tap()
    XCTAssertTrue(element("history-day-ready", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Completed"].exists)
    XCTAssertTrue(app.staticTexts["Not checked off"].exists)
    XCTAssertTrue(
      app.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-day-occurrence-"))
        .firstMatch.exists)
    XCTAssertFalse(app.buttons["Delete"].exists)
    XCTAssertFalse(app.buttons["Undo"].exists)

    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))
  }

  @MainActor
  func testEmptyHistoryDayShowsBothSectionEmptyStates() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-empty"])
    waitForReadyState(in: app)
    primaryDestination("History", in: app).tap()
    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))

    element("history-day-2026-10-28", in: app).tap()
    XCTAssertTrue(element("history-day-ready", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["No Goals were planned for this day."].exists)
    XCTAssertTrue(app.staticTexts["No iIndulged entries were recorded."].exists)
  }

  @MainActor
  func testHistoryDayFailureRetriesWithoutReplacingWeek() throws {
    let app = launchApplication(arguments: ["--ui-test-history-day-read-failure"])
    waitForReadyState(in: app)
    primaryDestination("History", in: app).tap()
    XCTAssertTrue(element("history-week-range", in: app).waitForExistence(timeout: 5))

    element("history-day-2026-10-28", in: app).tap()
    XCTAssertTrue(app.staticTexts["This day couldn’t be refreshed"].waitForExistence(timeout: 5))
    app.buttons["Try Again"].tap()
    XCTAssertTrue(element("history-day-ready", in: app).waitForExistence(timeout: 5))
  }

  @MainActor
  func testEmptyMyGoalsShowsExplicitWeekContext() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-empty"])
    waitForReadyState(in: app)

    primaryDestination("My Goals", in: app).tap()

    XCTAssertTrue(element("my-goals-week-context", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["No Goals planned for this week yet"].exists)
    let context = element("my-goals-week-context", in: app).label
    XCTAssertTrue(context.contains("This week"))
    XCTAssertTrue(context.contains("through"))
  }

  @MainActor
  func testPopulatedMyGoalsShowsGoalsInPlanOrderWithEditingControls() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)

    primaryDestination("My Goals", in: app).tap()

    XCTAssertTrue(elementWithLabel("Swim, Weekly", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(elementWithLabel("Walk, Daily", in: app).exists)
    XCTAssertTrue(elementWithLabel("Read, 3 days per week", in: app).exists)
    XCTAssertTrue(app.buttons["Add Goal"].exists)
  }

  @MainActor
  func testMyGoalsAddsAndEditsAGoalWithFrequencyControls() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-empty"])
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()

    app.buttons["Add Goal"].tap()
    let name = element("goal-name-field", in: app)
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("Stretch")
    app.buttons["Add"].tap()
    XCTAssertTrue(elementWithLabel("Stretch, Daily", in: app).waitForExistence(timeout: 5))

    app.buttons["Edit Stretch"].tap()
    app.buttons["Custom"].tap()
    XCTAssertTrue(element("goal-custom-target", in: app).exists)
    app.buttons["Save"].tap()
    XCTAssertTrue(app.buttons["Edit Stretch"].waitForExistence(timeout: 5))
    app.buttons["Edit Stretch"].tap()
    XCTAssertTrue(app.buttons["Custom"].isSelected)
    XCTAssertEqual(element("goal-custom-target", in: app).label, "2 days per week")
    app.buttons["Cancel"].tap()

    primaryDestination("My Day", in: app).tap()
    XCTAssertTrue(
      elementWithLabel("Stretch, Not complete today, 0 of 2", in: app)
        .waitForExistence(timeout: 5))
  }

  @MainActor
  func testMyGoalsFailedSaveKeepsDraftAndRetriesCalmly() throws {
    let app = launchApplication(arguments: ["--ui-test-my-goals-mutation-failure"])
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()

    app.buttons["Add Goal"].tap()
    let name = element("goal-name-field", in: app)
    name.tap()
    name.typeText("Stretch")
    app.buttons["Add"].tap()
    XCTAssertTrue(
      app.staticTexts["Couldn’t save this Goal. Please try again."].waitForExistence(timeout: 5))
    XCTAssertEqual(name.value as? String, "Stretch")
    app.buttons["Add"].tap()
    XCTAssertTrue(elementWithLabel("Stretch, Daily", in: app).waitForExistence(timeout: 5))
  }

  @MainActor
  func testMyGoalsShowsManageableGuidanceWithoutBlockingAdditions() throws {
    let app = launchApplication(arguments: ["--ui-test-my-goals-many"])
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()

    XCTAssertTrue(element("my-goals-manageable-guidance", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Add Goal"].isEnabled)
  }

  @MainActor
  func testMyGoalsRemovalExplainsHistoryAndCanCancelOrConfirm() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()

    app.buttons["Edit Swim"].tap()
    app.buttons["Remove Goal"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(
        NSPredicate(format: "label CONTAINS %@", "Earlier checkoffs will remain in History")
      ).firstMatch.waitForExistence(timeout: 5))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.navigationBars["Edit Goal"].exists)

    app.buttons["Remove Goal"].tap()
    app.buttons.matching(identifier: "Remove Goal").element(boundBy: 1).tap()
    XCTAssertTrue(app.buttons["Edit Walk"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Edit Swim"].exists)
    primaryDestination("My Day", in: app).tap()
    XCTAssertFalse(app.staticTexts["Swim"].exists)
  }

  @MainActor
  func testMyGoalsFailedReorderRollsBackThenRetriesAndRefreshesMyDay() throws {
    let app = launchApplication(arguments: ["--ui-test-my-goals-reorder-failure"])
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()

    app.buttons["Reorder Read"].tap()
    app.buttons["Move Read earlier"].tap()
    XCTAssertTrue(
      app.staticTexts["Couldn’t reorder these Goals. Please try again."]
        .waitForExistence(timeout: 5))
    XCTAssertGreaterThan(app.staticTexts["Read"].frame.minY, app.staticTexts["Walk"].frame.minY)

    app.buttons["Reorder Read"].tap()
    app.buttons["Move Read earlier"].tap()
    XCTAssertLessThan(app.staticTexts["Read"].frame.minY, app.staticTexts["Walk"].frame.minY)
    app.buttons["Reorder Read"].tap()
    app.buttons["Move Read earlier"].tap()
    primaryDestination("My Day", in: app).tap()
    XCTAssertLessThan(app.staticTexts["Read"].frame.minY, app.staticTexts["Swim"].frame.minY)
  }

  @MainActor
  func testMyGoalsReorderDisablesUnavailableDirections() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()

    app.buttons["Reorder Swim"].tap()
    XCTAssertFalse(app.buttons["Move Swim earlier"].isEnabled)

    app.terminate()
    app.launch()
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()
    app.buttons["Reorder Read"].tap()
    XCTAssertFalse(app.buttons["Move Read later"].isEnabled)
  }

  @MainActor
  func testMyGoalsFailedRemovalKeepsEditorAndRetries() throws {
    let app = launchApplication(arguments: ["--ui-test-my-goals-removal-failure"])
    waitForReadyState(in: app)
    primaryDestination("My Goals", in: app).tap()

    app.buttons["Edit Swim"].tap()
    app.buttons["Remove Goal"].tap()
    app.buttons.matching(identifier: "Remove Goal").element(boundBy: 1).tap()
    XCTAssertTrue(
      app.staticTexts["Couldn’t remove this Goal. Please try again."]
        .waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Edit Goal"].exists)

    app.buttons["Remove Goal"].tap()
    app.buttons.matching(identifier: "Remove Goal").element(boundBy: 1).tap()
    XCTAssertTrue(app.buttons["Edit Walk"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Edit Swim"].exists)
  }

  @MainActor
  func testMyGoalsReadFailureOffersCalmRetry() throws {
    let app = launchApplication(arguments: ["--ui-test-my-goals-read-failure"])
    waitForReadyState(in: app)

    primaryDestination("My Goals", in: app).tap()

    XCTAssertTrue(app.staticTexts["Your plan couldn’t be refreshed"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Try Again"].exists)
    XCTAssertFalse(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "SwiftData"))
        .firstMatch.exists)
  }

  @MainActor
  func testEmptyMyDayKeepsIIndulgedVisibleAndRoutesDirectlyToMyGoals() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-empty"])

    waitForReadyState(in: app)
    XCTAssertTrue(app.staticTexts["No Goals planned yet"].exists)
    XCTAssertTrue(app.staticTexts["iIndulged"].exists)
    for category in ["Junk Food", "Unhealthy Snacks", "Candy", "Alcohol", "Desserts"] {
      XCTAssertTrue(app.buttons["Add \(category) occurrence"].exists)
      XCTAssertTrue(app.buttons["Remove \(category) occurrence"].exists)
    }
    let addCandy = app.buttons["Add Candy occurrence"]
    let removeCandy = app.buttons["Remove Candy occurrence"]
    addCandy.tap()
    XCTAssertTrue(app.staticTexts["1 today"].waitForExistence(timeout: 5))
    removeCandy.tap()
    XCTAssertFalse(removeCandy.isEnabled)
    app.buttons["Go to My Goals"].tap()
    XCTAssertTrue(element("my-goals-screen", in: app).waitForExistence(timeout: 5))
    XCTAssertTrue(primaryDestination("My Goals", in: app).isSelected)
  }

  @MainActor
  func testPopulatedMyDayGroupsGoalsInPlanOrderAndShowsProgress() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])

    waitForReadyState(in: app)
    XCTAssertTrue(app.staticTexts["Today"].exists)
    XCTAssertTrue(app.staticTexts["This Week"].exists)
    XCTAssertTrue(app.staticTexts["Walk"].exists)
    XCTAssertTrue(elementWithLabel("Swim, Not complete today, 0 of 1", in: app).exists)
    XCTAssertTrue(elementWithLabel("Read, Complete today, 2 of 3", in: app).exists)
    XCTAssertTrue(app.staticTexts["iIndulged"].exists)
  }

  @MainActor
  func testGoalCheckoffsCompleteAndUndoAcrossFrequencyClasses() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)

    let walkComplete = elementWithLabel("Walk, Complete", in: app)
    walkComplete.tap()
    let walkIncomplete = elementWithLabel("Walk, Not complete", in: app)
    XCTAssertTrue(walkIncomplete.waitForExistence(timeout: 5))
    walkIncomplete.tap()
    XCTAssertTrue(walkComplete.waitForExistence(timeout: 5))

    let swimIncomplete = elementWithLabel("Swim, Not complete today, 0 of 1", in: app)
    swimIncomplete.tap()
    XCTAssertTrue(
      elementWithLabel("Swim, Complete today, 1 of 1", in: app).waitForExistence(timeout: 5))

    let readComplete = elementWithLabel("Read, Complete today, 2 of 3", in: app)
    readComplete.tap()
    let readIncomplete = elementWithLabel("Read, Not complete today, 1 of 3", in: app)
    XCTAssertTrue(readIncomplete.waitForExistence(timeout: 5))
    readIncomplete.tap()
    XCTAssertTrue(readComplete.waitForExistence(timeout: 5))
  }

  @MainActor
  func testGoalMutationFailureRestoresRowAndKeepsCalmGuidanceInline() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-mutation-failure"])
    waitForReadyState(in: app)

    let swim = elementWithLabel("Swim, Not complete today, 0 of 1", in: app)
    swim.tap()

    XCTAssertTrue(
      app.staticTexts["Couldn’t update this Goal. Please try again."].waitForExistence(timeout: 5))
    XCTAssertTrue(swim.exists)
    XCTAssertTrue(app.staticTexts["iIndulged"].exists)
    XCTAssertFalse(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "SwiftData"))
        .firstMatch.exists)
  }

  @MainActor
  func testIIndulgedCountersAddRemoveAndRespectZeroFloor() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-populated"])
    waitForReadyState(in: app)

    XCTAssertTrue(app.staticTexts["2 today"].exists)
    let addCandy = app.buttons["Add Candy occurrence"]
    let removeCandy = app.buttons["Remove Candy occurrence"]
    addCandy.tap()
    XCTAssertTrue(app.staticTexts["3 today"].waitForExistence(timeout: 5))
    removeCandy.tap()
    XCTAssertTrue(app.staticTexts["2 today"].waitForExistence(timeout: 5))

    let removeJunkFood = app.buttons["Remove Junk Food occurrence"]
    XCTAssertFalse(removeJunkFood.isEnabled)
  }

  @MainActor
  func testIIndulgedMutationFailureRestoresCountAndShowsGuidance() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-mutation-failure"])
    waitForReadyState(in: app)

    app.buttons["Add Junk Food occurrence"].tap()

    XCTAssertTrue(
      app.staticTexts["Couldn’t update this count. Please try again."].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["0 today"].exists)
    XCTAssertTrue(app.staticTexts["Goals"].exists)
  }

  @MainActor
  func testMyDayReadFailureKeepsStructureAndOffersRetry() throws {
    let app = launchApplication(arguments: ["--ui-test-my-day-read-failure"])

    waitForReadyState(in: app)
    XCTAssertTrue(app.staticTexts["Goals"].exists)
    XCTAssertTrue(app.staticTexts["Your day couldn’t be refreshed"].exists)
    XCTAssertTrue(app.buttons["Try Again"].exists)
    XCTAssertTrue(app.staticTexts["iIndulged"].exists)
    XCTAssertFalse(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "SwiftData")).firstMatch
        .exists)
  }

  @MainActor
  func testStartupFailureOffersCalmRetryWithoutExposingDetails() throws {
    let app = launchApplication(arguments: ["--ui-test-startup-failure"])

    XCTAssertTrue(element("app-startup-failed", in: app).waitForExistence(timeout: 5))
    XCTAssertFalse(element("app-ready", in: app).exists)
    XCTAssertTrue(app.staticTexts["Cadence couldn’t open"].exists)
    XCTAssertTrue(app.staticTexts["Your data has not been changed. Please try again."].exists)
    XCTAssertTrue(app.buttons["Try Again"].exists)
    let rawErrorText = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[c] %@", "error")
    ).firstMatch
    XCTAssertFalse(rawErrorText.exists)
  }

  @MainActor
  private func launchApplication(arguments: [String]) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = arguments
    addTeardownBlock {
      app.terminate()
    }
    app.launch()
    return app
  }

  @MainActor
  private func waitForReadyState(in app: XCUIApplication) {
    let terminalState = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier IN %@", ["app-ready", "app-startup-failed"])
    ).firstMatch
    let ready = element("app-ready", in: app)
    let failed = element("app-startup-failed", in: app)

    guard terminalState.waitForExistence(timeout: 10), ready.exists else {
      XCTFail(
        failed.exists
          ? "Cadence reported a startup failure" : "Cadence did not reach a terminal startup state")
      return
    }
  }

  @MainActor
  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier]
  }

  @MainActor
  private func elementWithLabel(_ label: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
  }

  @MainActor
  private func primaryDestination(
    _ label: String,
    in app: XCUIApplication
  ) -> XCUIElement {
    app.buttons[label]
  }

  @MainActor
  private func primaryDestinations(in app: XCUIApplication) -> XCUIElementQuery {
    app.buttons.matching(
      NSPredicate(format: "label IN %@", ["My Day", "My Goals", "History"])
    )
  }
}
