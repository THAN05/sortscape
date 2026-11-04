import XCTest
import StoreKitTest

final class StoreUITests: XCTestCase {
    @MainActor
    private func tap(_ id: String, app: XCUIApplication) {
        let button = app.buttons.matching(identifier: id).firstMatch
        for _ in 0..<10 {
            if button.exists && button.isHittable && button.isEnabled { button.tap(); return }
            if button.exists && button.frame.minY < 0 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Unable to reach \(id)")
    }
    @MainActor
    func testLocalStorePurchasesAndHintInventorySurviveRelaunch() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SortScape", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = XCUIApplication()
        app.launchEnvironment["SORTSCAPE_TEST_SAVE"] = UUID().uuidString
        app.launchEnvironment["SORTSCAPE_DISABLE_STORE_START"] = "0"
        app.launch()
        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 10))
        tap("store", app: app)
        XCTAssertTrue(app.buttons.matching(identifier: "buy-coins").firstMatch.waitForExistence(timeout: 10))
        tap("buy-coins", app: app)
        XCTAssertTrue(app.staticTexts["store-message"].waitForExistence(timeout: 5))
        tap("buy-hints", app: app)
        for _ in 0..<5 { app.swipeDown() }
        XCTAssertTrue(app.staticTexts["10 hint tokens"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1,000 coins"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Local store"; shot.lifetime = .keepAlways; add(shot)
        app.terminate(); app.launch()
        tap("play", app: app)
        tap("use-hint-token", app: app)
        XCTAssertTrue(app.staticTexts["1 moves"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["use-hint-token"].label.contains("9 tokens"))
        tap("undo", app: app)
        XCTAssertTrue(app.staticTexts["0 moves"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["use-hint-token"].label.contains("9 tokens"))
        app.terminate(); app.launch(); tap("store", app: app)
        XCTAssertTrue(app.staticTexts["9 hint tokens"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1,000 coins"].exists)
    }
}
