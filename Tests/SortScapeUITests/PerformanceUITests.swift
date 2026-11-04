import XCTest

@MainActor final class PerformanceUITests: XCTestCase {
    private func openPrivacy(_ app: XCUIApplication) {
        let link = app.buttons["analytics-settings"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        XCTAssertTrue(app.navigationBars["Analytics & diagnostics"].waitForExistence(timeout: 10))
    }

    private func tapSwitch(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 10), element.isHittable else {
            XCTFail("Expected a visible switch: \(element.identifier)")
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    func testAnalyticsPrivacyChoicesAndSortingGuideSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_DISABLE_TELEMETRY"] = "1"
        app.launch(); app.buttons["Settings"].tap()
        openPrivacy(app)
        let analytics = app.switches["analytics-setting"]
        XCTAssertTrue(analytics.waitForExistence(timeout: 5)); XCTAssertEqual(analytics.value as? String, "0")
        tapSwitch(analytics)
        XCTAssertEqual(analytics.value as? String, "1")
        let crashes = app.switches["crash-setting"]
        tapSwitch(crashes)
        XCTAssertEqual(crashes.value as? String, "1")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let guide = app.buttons["Learn to sort"]
        for _ in 0..<4 where !guide.isHittable { app.swipeUp() }
        guide.tap()
        XCTAssertTrue(app.staticTexts["Pick a piece"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap(); app.buttons["Ready to sort"].tap()
        openPrivacy(app)
        XCTAssertTrue(analytics.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Privacy choices"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate(); app.launch(); app.buttons["Settings"].tap()
        openPrivacy(app)
        XCTAssertTrue(analytics.waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["analytics-setting"].value as? String, "1")
        XCTAssertTrue(crashes.waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["crash-setting"].value as? String, "1")
    }
    func testForegroundLaunchPerformance() {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_DISABLE_STORE_START"] = "1"
        app.launchEnvironment["SORTSCAPE_DISABLE_ADS"] = "1"
        app.launchEnvironment["SORTSCAPE_DISABLE_TELEMETRY"] = "1"
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) { app.launch() }
        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
