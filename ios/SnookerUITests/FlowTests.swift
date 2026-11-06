import XCTest

/// Walks the app the way a player does: intro, setup, then the table.
final class FlowTests: XCTestCase {
    @MainActor
    func testIntroSetupThenTable() throws {
        let app = XCUIApplication()
        app.launch()

        // setup is built underneath the intro, so wait for the intro to go before tapping
        let intro = app.buttons["Snookerin. Keep score to lose to Raj."]
        XCTAssertTrue(intro.waitForNonExistence(timeout: 6), "the intro lasts three seconds")
        let start = app.buttons["START FRAME"]
        XCTAssertTrue(start.waitForExistence(timeout: 2), "setup follows the intro")
        XCTAssertTrue(app.buttons["Raj"].exists || app.buttons["Raj, seated"].exists, "saved players are offered")
        save(app, "setup")

        start.tap()
        let endVisit = app.buttons["END VISIT"]
        XCTAssertTrue(endVisit.waitForExistence(timeout: 3))
        XCTAssertFalse(app.segmentedControls.firstMatch.exists, "no player-count picker on the table")

        XCTAssertFalse(app.buttons["Pot yellow, 2 points"].isEnabled, "a visit starts on a red")
        app.buttons["Pot red, 1 point"].tap()
        XCTAssertTrue(app.buttons["Pot black, 7 points"].isEnabled, "a colour after a red")
        app.buttons["Pot black, 7 points"].tap()
        app.buttons["Pot red, 1 point"].tap()
        app.buttons["Pot pink, 6 points"].tap()
        endVisit.tap()
        app.buttons["Pot red, 1 point"].tap()
        app.buttons["FOUL, 5 POINTS"].tap()
        save(app, "table")

        app.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))
        save(app, "history")
        app.buttons["Done"].tap()
    }

    /// Screenshots land in the test report, and in SNOOKER_SHOTS on the Mac when set.
    @MainActor
    private func save(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SNOOKER_SHOTS"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
