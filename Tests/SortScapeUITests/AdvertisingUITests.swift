import XCTest

final class AdvertisingUITests: XCTestCase {
    @MainActor
    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_TEST_ADS"] = mode
        app.launch(); XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor
    private func tap(_ id: String, app: XCUIApplication) {
        let button = app.buttons.matching(identifier: id).firstMatch
        for _ in 0..<12 {
            if button.exists && button.isHittable && button.isEnabled { button.tap(); return }
            if button.exists && button.frame.minY < 0 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Unable to reach \(id)")
    }
    @MainActor
    func testRewardHintStartsDirectlyAndDoesNotDuplicate() {
        let app = launch("duplicate"); tap("play", app: app)
        tap("ad-hint", app: app)
        XCTAssertTrue(app.buttons["use-hint-token"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["use-hint-token"].label.contains("1 tokens"))
        tap("use-hint-token", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 5))
        tap("undo", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
        app.terminate(); app.launch(); tap("play", app: app)
        XCTAssertFalse(app.buttons["use-hint-token"].exists)
    }
    @MainActor
    func testRewardedBonusOnceAndNextLevelNavigation() {
        let app = launch("duplicate"); tap("play", app: app)
        for (source, destination) in [(0, 2), (1, 0), (2, 1)] { tap("vessel-\(source)", app: app); tap("vessel-\(destination)", app: app) }
        XCTAssertTrue(app.staticTexts["World restored!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ad-bonus-coins"].isHittable)
        capture("Completion ad offer", app: app)
        tap("ad-bonus-coins", app: app)
        XCTAssertFalse(app.buttons["ad-bonus-coins"].exists)
        XCTAssertTrue(app.staticTexts["ad-bonus-saved"].waitForExistence(timeout: 5))
        capture("Optional bonus reward", app: app)
        tap("next-world", app: app)
        XCTAssertTrue(app.staticTexts["Tidal Pools"].waitForExistence(timeout: 5))
        let rewindOffer = app.buttons["ad-undo"]
        XCTAssertTrue(app.buttons["ad-hint"].isHittable)
        XCTAssertTrue(rewindOffer.isHittable)
        capture("Gameplay ad offers", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["60 coins"].waitForExistence(timeout: 5))
    }
    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testUnavailableAndPrivacyDeniedAdsNeverBlockOfflineGameplay() {
        for mode in ["failure", "denied"] {
            let app = launch(mode); tap("play", app: app)
            tap("ad-hint", app: app)
            XCTAssertFalse(app.buttons["use-hint-token"].exists)
            tap("vessel-0", app: app); tap("vessel-2", app: app)
            XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["0 coins"].exists)
            app.terminate()
        }
    }
    @MainActor
    func testOptionalRewindTokenWorksWithoutChangingFreeUndo() {
        let app = launch("success"); tap("play", app: app)
        for (source, destination) in [(0, 2), (1, 0)] { tap("vessel-\(source)", app: app); tap("vessel-\(destination)", app: app) }
        tap("ad-undo", app: app)
        tap("use-rewind-token", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["use-rewind-token"].exists)
        tap("vessel-0", app: app); tap("vessel-2", app: app); tap("undo", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
    }
}
