//
//  ScreenshotSweepTests.swift
//  Headache TrackerUITests
//
//  Created by Colin Campbell on 7/3/26.
//

import XCTest

/// Drives the seeded app through every screen and captures a screenshot of
/// each as a `.keepAlways` attachment, for visual review of the UI-polish
/// pass. Launch with `--uitest-seed` so cards render with real content.
final class ScreenshotSweepTests: XCTestCase {

  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = true
    app = XCUIApplication()
    app.launchArguments += ["--uitest-seed"]
    if let theme = ProcessInfo.processInfo.environment["UITEST_THEME"] {
      app.launchArguments += ["--uitest-theme", theme]
    }
    app.launch()
  }

  func testCaptureEveryScreen() throws {
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Tab bar never appeared")

    // A location permission prompt can appear a few seconds after launch and
    // makes the app non-idle (hanging screenshots). Dismiss it via the
    // springboard before doing anything else.
    dismissSystemLocationPrompt()

    _ = app.staticTexts["Track"].waitForExistence(timeout: 10)
    sleep(4)

    // 1. Track tab (risk, why, check-in, severity).
    capture("01-Track")

    // 2. Analyze tab (insights top-3, graphs, statistics).
    tabBar.buttons["Analyze"].tap()
    sleep(2)
    capture("02-Analyze")
    // Scroll down to the graphs.
    app.swipeUp()
    app.swipeUp()
    sleep(1)
    capture("02b-AnalyzeGraphs")
    app.swipeDown()
    app.swipeDown()
    sleep(1)

    // 2b. A trigger insight detail (tap the first insight's title).
    let insightTitle = app.staticTexts["Sleep Duration"].firstMatch
    if insightTitle.waitForExistence(timeout: 5) {
      insightTitle.tap()
      if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5), !app.staticTexts["Insights"].exists {
        sleep(2)
        capture("03-TriggerDetail")
        back()
      }
    }
    // 2c. All Insights list.
    tapText("All Insights")
    sleep(2)
    if app.navigationBars["Insights"].waitForExistence(timeout: 4) {
      capture("04-Insights")
      back()
    }

    // 3. Headaches tab + detail.
    tabBar.buttons["Headaches"].tap()
    sleep(2)
    capture("05-Headaches")
    // Tap the first headache's onset date (definitely inside its
    // NavigationLink row — app.cells.firstMatch can match a section header).
    let onsetDate = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2026'")).firstMatch
    if onsetDate.waitForExistence(timeout: 5) {
      let editButton = app.navigationBars.buttons["Edit"]
      onsetDate.tap()
      if !editButton.waitForExistence(timeout: 5) {
        onsetDate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        _ = editButton.waitForExistence(timeout: 5)
      }
      sleep(2)
      capture("06-HeadacheDetail")
      back()
    }

    // 4. Settings + subscreens.
    tabBar.buttons["Settings"].tap()
    sleep(2)
    capture("07-Settings")
    if tapText("My Predictors") {
      sleep(2)
      capture("08-Predictors")
      back()
    }
    if tapText("Export for Clinician") {
      sleep(1)
      capture("09-Export")
      back()
    }

    // 5. Daily check-in sheet from the Track tab.
    tabBar.buttons["Track"].tap()
    sleep(2)
    if let edit = app.buttons.matching(identifier: "Edit").allElementsBoundByIndex.first,
       edit.waitForExistence(timeout: 3) {
      edit.tap()
      sleep(2)
      capture("10-DailyCheckIn")
    }
  }

  // MARK: Helpers

  /// Taps the location permission alert if the system presents one.
  private func dismissSystemLocationPrompt() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    for label in ["Allow While Using App", "Allow Once", "Don't Allow"] {
      let button = springboard.buttons[label]
      if button.waitForExistence(timeout: 8) {
        button.tap()
        return
      }
    }
  }


  /// Taps a tappable element carrying the given label, trying buttons,
  /// static texts, and cells. Returns whether it tapped.
  @discardableResult
  private func tapText(_ label: String) -> Bool {
    for query in [app.buttons, app.staticTexts, app.cells] {
      let element = query[label]
      if element.exists && element.isHittable {
        element.tap()
        return true
      }
    }
    return false
  }

  /// Waits until the Headaches list's large title is gone (we've navigated
  /// into a detail). Returns whether it vanished.
  private func waitForListTitleToVanish() -> Bool {
    let listTitle = app.navigationBars["Headaches"]
    let gone = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: gone, object: listTitle)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }

  private func back() {
    let backButton = app.navigationBars.buttons.firstMatch
    if backButton.exists {
      backButton.tap()
      sleep(1)
    }
  }

  private func capture(_ name: String) {
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

}
