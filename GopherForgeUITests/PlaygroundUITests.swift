import XCTest

@MainActor final class PlaygroundUITests: XCTestCase {
    func testCaptureSharedPlaygroundLocalRun() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "projects", "-GopherForgeEmptyLibrary"]
        app.launch()
        let entry = app.buttons["projects.playground"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let connection = app.buttons["Room & AI connection"]
        XCTAssertTrue(connection.waitForExistence(timeout: 5)); connection.tap()
        if app.buttons["Close room"].exists {
            app.buttons["Close room"].tap()
            XCTAssertTrue(app.buttons["playground.create"].waitForExistence(timeout: 15))
        }
        let create = app.buttons["playground.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5)); create.tap()
        let close = app.buttons["Close room"]
        XCTAssertTrue(close.waitForExistence(timeout: 20))
        connection.tap()
        let run = app.buttons["playground.run"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true AND isEnabled == true"), object: run)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        run.tap()
        let began = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "Room created for one hour. Share Edit/View deliberately; keep your own copy."), object: app.staticTexts["playground.status"])
        if XCTWaiter.wait(for: [began], timeout: 3) != .completed {
            run.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let finished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Local run finished"),
            object: app.staticTexts["playground.status"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 45), .completed)
        let output = app.staticTexts["playground.localOutput"]
        XCTAssertTrue(output.waitForExistence(timeout: 5))
        XCTAssertTrue(output.label.contains("Hello from my device"), output.label)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "playground-room-local-run"; attachment.lifetime = .keepAlways; add(attachment)
        connection.tap()
        if !close.isHittable { app.swipeUp() }
        close.tap()
        XCTAssertTrue(create.waitForExistence(timeout: 15))
    }
    func testProjectsOpensLocalPlaygroundAndRunsOnlyAfterTheButton() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "projects", "-GopherForgeEmptyLibrary"]
        app.launch()
        let entry = app.buttons["projects.playground"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.navigationBars["Playground"].waitForExistence(timeout: 5))
        let run = app.buttons["playground.run"]
        if !run.isHittable { app.swipeUp() }
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        // A previous local result is intentionally restored after relaunch.
        // Require this button press to finish a new run, rather than accepting
        // the old Output's mere presence as evidence of execution.
        let finished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Local run finished"),
            object: app.staticTexts["playground.status"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 45), .completed)
        let output = app.staticTexts["playground.localOutput"]
        if !output.waitForExistence(timeout: 45) { app.swipeUp() }
        XCTAssertTrue(output.waitForExistence(timeout: 10))
        XCTAssertTrue(output.label.contains("Hello from my device"), output.label)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "playground-local-run"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLearningProgressShareShowsPreviewWithoutPublishingOnOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let entry = app.buttons["learn.shareProgress"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        XCTAssertTrue(app.navigationBars["Share learning progress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["learning.share.publish"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Share progress link"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "progress-share-preview"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
