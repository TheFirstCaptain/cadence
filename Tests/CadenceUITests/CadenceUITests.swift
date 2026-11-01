import XCTest

final class CadenceUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testAppLaunchesWithMyDaySelected() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-my-day-empty"]
    app.launch()

    waitForReadyState(in: app)
    XCTAssertTrue(app.navigationBars["My Day"].exists)
    XCTAssertEqual(primaryDestinations(in: app).count, 3)
    XCTAssertTrue(primaryDestination("My Day", in: app).isSelected)
  }

  @MainActor
  func testNavigatesAcrossAllPrimaryTabs() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-my-day-empty"]
    app.launch()

    waitForReadyState(in: app)

    let myGoalsTab = primaryDestination("My Goals", in: app)
    XCTAssertTrue(myGoalsTab.exists)
    myGoalsTab.tap()
    XCTAssertTrue(app.staticTexts["my-goals-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(myGoalsTab.isSelected)

    let historyTab = primaryDestination("History", in: app)
    historyTab.tap()
    XCTAssertTrue(app.staticTexts["history-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(historyTab.isSelected)

    let myDayTab = primaryDestination("My Day", in: app)
    myDayTab.tap()
    XCTAssertTrue(app.navigationBars["My Day"].waitForExistence(timeout: 5))
    XCTAssertTrue(myDayTab.isSelected)
  }

  @MainActor
  func testEmptyMyDayKeepsIIndulgedVisibleAndRoutesDirectlyToMyGoals() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-my-day-empty"]
    app.launch()

    waitForReadyState(in: app)
    XCTAssertTrue(app.staticTexts["No Goals planned yet"].exists)
    XCTAssertTrue(app.staticTexts["iIndulged"].exists)
    app.buttons["Go to My Goals"].tap()
    XCTAssertTrue(app.staticTexts["my-goals-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(primaryDestination("My Goals", in: app).isSelected)
  }

  @MainActor
  func testPopulatedMyDayGroupsGoalsInPlanOrderAndShowsProgress() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-my-day-populated"]
    app.launch()

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
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-my-day-populated"]
    app.launch()
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
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-my-day-mutation-failure"]
    app.launch()
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
  func testMyDayReadFailureKeepsStructureAndOffersRetry() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-my-day-read-failure"]
    app.launch()

    waitForReadyState(in: app)
    XCTAssertTrue(app.staticTexts["Goals"].exists)
    XCTAssertTrue(app.staticTexts["Your Goals couldn’t be refreshed"].exists)
    XCTAssertTrue(app.buttons["Try Again"].exists)
    XCTAssertTrue(app.staticTexts["iIndulged"].exists)
    XCTAssertFalse(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "SwiftData")).firstMatch
        .exists)
  }

  @MainActor
  func testStartupFailureOffersCalmRetryWithoutExposingDetails() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-startup-failure"]
    app.launch()

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
