import XCTest

/// Captures the App Store screenshots by driving the real app.
///
/// Not a test of behaviour — every assertion here exists so the run fails
/// loudly rather than quietly attaching a picture of the wrong screen. Store
/// listings are the one place where a stale or empty screenshot is invisible
/// until a reviewer sees it.
///
/// Run it with `scripts/app_store_screenshots.sh`, which drives the device
/// sizes Apple asks for and collects the attachments.
final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// One ordered walk rather than a test per screen: the shots build on each
    /// other — the library needs projects in it, the unit needs the course open
    /// — and re-launching between them would throw that away.
    func testCaptureTheListingScreenshots() {
        launch(section: "learn")

        XCTAssertTrue(app.waitForElement(app.buttons["unit.core"]), "the course should be on screen")
        capture("01-course")

        app.buttons["unit.concurrency"].tap()
        XCTAssertTrue(
            app.buttons["lesson.concurrency.channel-close"].waitForExistence(timeout: 15),
            "the unit should list its lessons"
        )
        capture("02-unit")

        app.buttons["lesson.concurrency.channel-close"].tap()
        // Keyed on the identifier rather than on a heading: the section titles
        // are uppercased for display, and a screenshot run that waits for the
        // wrong casing fails somewhere unrelated.
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.lessonCheck].waitForExistence(timeout: 15),
            "a compile lesson should offer Check"
        )
        capture("03-lesson")

        launch(section: "learn", screen: "lab")
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.labScenario("unbuffered-rendezvous")]
                .waitForExistence(timeout: 15),
            "the lab should offer its scenarios"
        )
        capture("04-lab")

        launch(section: "projects")
        openTemplate("tested-package")
        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(
            editor.waitForExistence(timeout: 15),
            "opening a template should land in the editor"
        )
        XCTAssertFalse(
            (editor.value as? String ?? "").isEmpty,
            "the editor should hold the template's source"
        )
        capture("05-workspace")

        launch(section: "projects")
        openTemplate("worker-pool")

        launch(section: "projects")
        let library = app.buttons["projects.library"]
        XCTAssertTrue(app.waitForElement(library), "the dashboard should reach the library")
        library.tap()
        XCTAssertTrue(
            app.staticTexts["Unfiled"].waitForExistence(timeout: 15),
            "the library should list the projects that were opened"
        )
        capture("06-projects")
    }

    // MARK: - Helpers

    private func launch(section: String, screen: String? = nil) {
        // No terminate first: `launch()` already relaunches, and terminating an
        // app that has not started yet fails the run before it reaches a screen.
        var arguments = ["-GopherForgeSection", section]
        if let screen { arguments += ["-GopherForgeScreen", screen] }
        app.launchArguments = arguments
        app.launch()
    }

    private func openTemplate(_ id: String) {
        let create = app.buttons[AccessibilityIdentifier.newProject]
        XCTAssertTrue(app.waitForElement(create), "the dashboard should offer a way to start")
        create.tap()

        let template = app.buttons["template.\(id)"]
        XCTAssertTrue(template.waitForExistence(timeout: 15), "template \(id) should be offered")
        template.tap()
    }

    /// Named with a leading number so the files sort into listing order once
    /// they are exported.
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
