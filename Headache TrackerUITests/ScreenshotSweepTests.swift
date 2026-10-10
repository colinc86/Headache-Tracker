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
    // Pin a theme: unit tests share the simulator and can leave another one
    // saved in the shared defaults.
    app.launchArguments += ["--uitest-theme", ProcessInfo.processInfo.environment["UITEST_THEME"] ?? "System"]
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

    // 1. Track tab (hero, summary, ribbon, drivers, today, log bar).
    capture("01-Track")
    app.swipeUp()
    sleep(1)
    capture("01a-TrackLower")
    app.swipeDown()
    sleep(1)

    // 1b. Signals (behind the forecast hero) and the what-if simulator.
    let hero = app.descendants(matching: .any)["track.hero"]
    if hero.waitForExistence(timeout: 5) {
      hero.tap()
      if app.navigationBars["Signals"].waitForExistence(timeout: 5) {
        sleep(2)
        capture("01b-Signals")
        scrollTo("What If…")
        if tapText("What If…") {
          sleep(3)
          capture("01c-WhatIf")
          app.swipeUp()
          sleep(2)
          capture("01d-WhatIfSignals")
          back()
        }
        back()
      }
    }

    // 2. Profile tab: signature, portrait, triggers, rhythm, shape, month, forecast.
    tabBar.buttons["Profile"].tap()
    sleep(3)
    capture("02-Profile")
    app.swipeUp()
    sleep(1)
    capture("02b-ProfileTriggers")
    if tapText("Show the data") {
      sleep(2)
      capture("02c-ProfileTriggerData")
    }
    for index in 0 ..< 4 {
      app.swipeUp()
      sleep(1)
      capture("02d-Profile-\(index)")
    }

    // 3. Headaches tab (stats overview above the list) + detail.
    tabBar.buttons["Headaches"].tap()
    sleep(2)
    capture("05-Headaches")
    if tapText("Severity, onset, and duration charts") {
      sleep(1)
      app.swipeUp()
      sleep(1)
      capture("05b-HeadacheCharts")
      app.swipeDown()
      app.swipeDown()
      sleep(1)
    }
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
      // The progression chart sits below the fold; scroll it into view so the
      // sweep actually covers it.
      scrollTo("Progression")
      capture("06b-Progression")
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
  }

  /// The Track tab during a headache: the live hero and the log bar's
  /// severities and Resolve.
  func testCaptureActiveHeadache() throws {
    app.terminate()
    app.launchArguments += ["--uitest-active-headache"]
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
    dismissSystemLocationPrompt()
    sleep(4)
    capture("01e-TrackActive")
    app.swipeUp()
    sleep(1)
    capture("01f-TrackActiveCards")
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

  /// Swipes up until an element carrying the given label is on screen.
  ///
  /// - Parameters:
  ///   - label: The label to look for.
  ///   - maximumSwipes: How many swipes to try before giving up.
  /// - Returns: Whether the element became visible.
  @discardableResult
  private func scrollTo(_ label: String, maximumSwipes: Int = 6) -> Bool {
    let element = app.staticTexts[label]
    for _ in 0 ..< maximumSwipes {
      if element.exists && element.isHittable {
        sleep(1)
        return true
      }
      app.swipeUp()
    }
    sleep(1)
    return element.exists && element.isHittable
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
