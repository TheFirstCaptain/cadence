import XCTest

final class CadenceUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testAppLaunchesWithMyDaySelected() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.staticTexts["my-day-screen"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.tabBars.buttons.count, 3)
    XCTAssertTrue(app.tabBars.buttons["My Day"].isSelected)
  }

  @MainActor
  func testNavigatesAcrossAllPrimaryTabs() throws {
    let app = XCUIApplication()
    app.launch()

    let myGoalsTab = app.tabBars.buttons["My Goals"]
    XCTAssertTrue(myGoalsTab.waitForExistence(timeout: 5))
    myGoalsTab.tap()
    XCTAssertTrue(app.staticTexts["my-goals-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(myGoalsTab.isSelected)

    let historyTab = app.tabBars.buttons["History"]
    historyTab.tap()
    XCTAssertTrue(app.staticTexts["history-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(historyTab.isSelected)

    let myDayTab = app.tabBars.buttons["My Day"]
    myDayTab.tap()
    XCTAssertTrue(app.staticTexts["my-day-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(myDayTab.isSelected)
  }

  @MainActor
  func testStartupFailureOffersCalmRetryWithoutExposingDetails() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-test-startup-failure"]
    app.launch()

    XCTAssertTrue(app.staticTexts["Cadence couldn’t open"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Your data has not been changed. Please try again."].exists)
    XCTAssertTrue(app.buttons["Try Again"].exists)
    let rawErrorText = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[c] %@", "error")
    ).firstMatch
    XCTAssertFalse(rawErrorText.exists)
  }
}
