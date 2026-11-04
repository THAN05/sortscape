import XCTest

final class ProgressionUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor
    private func tap(_ id: String, app: XCUIApplication) {
        let button = app.buttons.matching(identifier: id).firstMatch
        for _ in 0..<8 {
            if button.exists {
                if !button.isEnabled {
                    let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
                    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed)
                }
                if button.isHittable { button.tap(); return }
                if button.frame.minY < app.frame.minY { app.swipeDown() } else { app.swipeUp() }
            } else if !button.waitForExistence(timeout: 1) {
                // Form creates offscreen rows lazily; scroll before declaring a missing control.
                app.swipeUp()
            }
        }
        XCTFail("Unable to reach button \(id)")
    }
    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testUnfinishedBoardAndUndoRecoverAfterTermination() {
        let app = launch()
        tap("play", app: app)
        tap("vessel-0", app: app); tap("vessel-2", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        tap("play", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 5))
        tap("undo", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        tap("play", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSolveRewardUnlockAndRelaunchPersistence() throws {
        let app = launch(); capture("Home", app: app)
        tap("explore", app: app)
        XCTAssertFalse(app.buttons["level-2"].isEnabled)
        tap("level-1", app: app)
        XCTAssertTrue(app.buttons["vessel-0"].waitForExistence(timeout: 5))
        capture("Gameplay", app: app)
        tap("vessel-0", app: app); tap("vessel-2", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 3))
        tap("undo", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
        tap("vessel-0", app: app); tap("vessel-2", app: app)
        tap("restart", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
        for (source, destination) in [(0,2), (1,0), (2,1)] {
            tap("vessel-\(source)", app: app); tap("vessel-\(destination)", app: app)
        }
        XCTAssertTrue(app.staticTexts["World restored!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["+35 coins"].exists)
        XCTAssertTrue(app.staticTexts["3 moves"].exists)
        capture("Completion", app: app)
        tap("next-world", app: app)
        XCTAssertTrue(app.staticTexts["Tidal Pools"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 moves"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["35 coins"].waitForExistence(timeout: 10))
        tap("explore", app: app)
        XCTAssertTrue(app.buttons["level-2"].isEnabled)
        XCTAssertFalse(app.buttons["level-3"].isEnabled)
    }

    @MainActor
    func testPauseSettingsHintsAndBackgroundResume() throws {
        let app = launch()
        tap("play", app: app)
        tap("hint", app: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Try vessel")).firstMatch.waitForExistence(timeout: 5))
        tap("pause", app: app)
        XCTAssertTrue(app.navigationBars["Take a breath"].waitForExistence(timeout: 5))
        app.switches["sound-setting"].tap(); app.switches["haptic-setting"].tap(); app.switches["motion-setting"].tap()
        capture("Pause settings", app: app)
        tap("resume", app: app)
        tap("restart", app: app)
        tap("vessel-0", app: app); tap("vessel-1", app: app)
        XCTAssertTrue(app.staticTexts["That piece needs a matching top or an empty vessel."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0 moves"].exists)
        tap("vessel-2", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 8))
        tap("resume", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 3))
        tap("undo", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
    }
    @MainActor
    func testLargeTextAndAccessibleVessels() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 10))
        capture("Large text home", app: app)
        tap("play", app: app)
        let vessel = app.buttons["vessel-0"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 5))
        XCTAssertTrue(vessel.label.contains("coral diamond"))
        XCTAssertGreaterThanOrEqual(vessel.frame.width, 44)
        XCTAssertGreaterThanOrEqual(vessel.frame.height, 44)
        capture("Large text gameplay", app: app)
        tap("vessel-0", app: app); tap("vessel-2", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 3))
        tap("undo", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testRepresentativeDifficultyTiersAndStarReplay() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_TEST_CAMPAIGN"] = "completed"
        app.launch()
        XCTAssertTrue(app.buttons["explore"].waitForExistence(timeout: 15))
        for (tier, id) in [("beginner",1), ("easy",21), ("medium",41), ("hard",66), ("expert",86)] {
            tap("explore", app: app)
            tap("tier-picker", app: app); tap("tier-\(tier)", app: app)
            XCTAssertTrue(app.buttons["level-\(id)"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["level-\(id)"].label.contains("3 of 3 stars"))
            capture("\(tier.capitalized) selection", app: app)
            tap("level-\(id)", app: app)
            XCTAssertTrue(app.buttons["vessel-0"].waitForExistence(timeout: 5))
            capture("\(tier.capitalized) representative", app: app)
            tap("hint", app: app)
            let message = app.staticTexts["game-message"]
            let hint = NSPredicate(format: "label BEGINSWITH %@", "Try vessel")
            expectation(for: hint, evaluatedWith: message)
            waitForExpectations(timeout: 5)
            let numbers = message.label.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            XCTAssertEqual(numbers.count, 2)
            // Hint has already selected the suggested source; tap only its destination.
            tap("vessel-\(numbers[1] - 1)", app: app)
            XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 3))
            tap("undo", app: app)
            XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
            tap("pause", app: app); tap("Back to home", app: app)
            XCTAssertTrue(app.buttons["explore"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testIslandDirectSpendingAndRestartPersistence() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_TEST_CAMPAIGN"] = "restoration-starter"
        app.launch()
        tap("play", app: app)
        for (source, destination) in [(0,2), (1,0), (2,1)] {
            tap("vessel-\(source)", app: app); tap("vessel-\(destination)", app: app)
        }
        XCTAssertTrue(app.staticTexts["+35 coins"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rewards saved automatically"].exists)
        XCTAssertFalse(app.buttons["collect-rewards"].exists)
        XCTAssertTrue(app.buttons["next-world"].isHittable)
        XCTAssertTrue(app.buttons["completion-island"].isHittable)
        app.buttons["completion-island"].tap()
        XCTAssertTrue(app.staticTexts["1,035 coins"].waitForExistence(timeout: 5))
        tap("restore-pathways", app: app)
        XCTAssertTrue(app.staticTexts["10% restored"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["835 coins"].exists)
        XCTAssertTrue(app.staticTexts["3 stars"].exists)
        capture("First restoration", app: app)
        tap("restore-trees", app: app)
        XCTAssertTrue(app.alerts["A little more to go"].waitForExistence(timeout: 3))
        tap("Got it", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["island"].waitForExistence(timeout: 10))
        tap("island", app: app)
        XCTAssertTrue(app.staticTexts["10% restored"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["835 coins"].exists)
        XCTAssertFalse(app.buttons["restore-pathways"].exists)
    }
    @MainActor
    func testAllTenDecorationsCanBeBuiltWithFundedWallet() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_TEST_CAMPAIGN"] = "restoration-funded"
        app.launch()
        tap("island", app: app)
        for id in ["pathways", "trees", "flowerGarden", "cottage", "bridge", "picnic", "fountain", "windmill", "dock", "lighthouse"] {
            tap("restore-\(id)", app: app)
        }
        XCTAssertTrue(app.staticTexts["100% restored"].waitForExistence(timeout: 5))
        app.swipeDown(); app.swipeDown(); app.swipeDown(); app.swipeDown()
        capture("Restored island", app: app)
        app.terminate(); app.launch(); tap("island", app: app)
        XCTAssertTrue(app.staticTexts["100% restored"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["575 coins"].exists)
        capture("Restored island after relaunch", app: app)
    }
    @MainActor
    func testInsufficientIslandFundsCannotChangeBalance() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_TEST_CAMPAIGN"] = "restoration-budget"
        app.launch(); tap("island", app: app)
        XCTAssertTrue(app.staticTexts["0 coins"].waitForExistence(timeout: 5))
        tap("restore-bridge", app: app)
        XCTAssertTrue(app.alerts["A little more to go"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1600 more coins")).firstMatch.exists)
        tap("Got it", app: app)
        XCTAssertTrue(app.staticTexts["0 coins"].exists)
        XCTAssertTrue(app.staticTexts["10% restored"].exists)
        capture("Insufficient coins", app: app)
    }

}
