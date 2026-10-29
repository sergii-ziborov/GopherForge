import XCTest

@MainActor final class PlaygroundUITests: XCTestCase {
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
