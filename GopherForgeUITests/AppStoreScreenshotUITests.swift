import XCTest

/// Captures the App Store screenshots by driving the real app.
///
/// Not a test of behaviour — every assertion here exists so the run fails
/// loudly rather than quietly attaching a picture of the wrong screen. Store
/// listings are the one place where a stale or empty screenshot is invisible
/// until a reviewer sees it.
///
/// The order is the argument. The first two pictures are real build output,
/// because the thing worth paying for is a compiler that runs on the device,
/// and a listing that opens with a lesson list reads as one more tutorial app.
/// The course comes third, once the claim has been shown rather than stated.
///
/// Run it with `scripts/app_store_screenshots.sh`, which drives the device
/// sizes Apple asks for and collects the attachments.
/// Main-actor isolated because every XCUIElement query is: in Swift 6 a helper
/// that reaches one from a nonisolated method is a concurrency error, reported
/// as a compiler failure with no readable diagnostic behind it.
@MainActor
final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    /// A real Go build under the interpreter, on a cold cache, on whatever
    /// machine this runs on. Generous on purpose: the alternative to waiting is
    /// a screenshot of a spinner.
    private let buildTimeout: TimeInterval = 600

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// One ordered walk rather than a test per screen: the shots build on each
    /// other — the library needs projects in it, the second build reuses the
    /// first one's cache — and re-launching between them would throw that away.
    func testCaptureTheListingScreenshots() {
        // The worker pool rather than the smallest template that would run.
        // The opening picture is the one that has to carry the claim, and a
        // seven-line file leaves most of a 13" editor empty — this one fills
        // it with goroutines, a channel and a WaitGroup, which is also what
        // the README says is in it.
        launch(section: "projects")
        openTemplate("worker-pool")
        expectSource()

        // The picture the listing opens with: Go, compiled and run here.
        runPhase("run")
        capture("01-compiler")

        // The one that shows it was not a trick: a real test run, reported per
        // case. It needs the template that ships tests.
        launch(section: "projects")
        openTemplate("tested-package")
        expectSource()

        runPhase("test")
        capture("02-tests")

        captureProblems()

        launch(section: "learn")
        XCTAssertTrue(app.waitForElement(app.buttons["unit.core"]), "the course should be on screen")
        capture("03-course")

        app.buttons["unit.concurrency"].tap()
        let lesson = app.buttons["lesson.concurrency.channel-close"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 30), "the unit should list its lessons")
        capture("07-unit")

        lesson.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.lessonCheck].waitForExistence(timeout: 30),
            "a compile lesson should offer Check"
        )
        capture("04-lesson")

        launch(section: "learn", screen: "lab")
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.labScenario("unbuffered-rendezvous")]
                .waitForExistence(timeout: 30),
            "the lab should offer its scenarios"
        )
        capture("05-lab")

        launch(section: "projects")
        let library = app.buttons["projects.library"]
        XCTAssertTrue(app.waitForElement(library), "the dashboard should reach the library")
        library.tap()
        XCTAssertTrue(
            app.staticTexts["Unfiled"].waitForExistence(timeout: 30),
            "the library should list the projects that were opened"
        )
        capture("06-projects")
    }

    /// Breaks the open project on purpose, builds it, and photographs what the
    /// compiler said.
    ///
    /// An empty Problems pane is not a picture of anything, so the diagnostic
    /// has to be real — and it is produced by breaking the file and building
    /// rather than by staging a message, so the shot cannot outlive the parser
    /// that produced it. `declared and not used` is the one Go is best known
    /// for, and the one a newcomer meets first.
    ///
    /// This runs after the two build shots and before the course, so the
    /// screenshots that claim a working compiler are taken while the project
    /// still compiles.
    private func captureProblems() {
        let editor = app.textViews[AccessibilityIdentifier.editor]

        // iPhone shows the panes as full-height tabs, so the test run that was
        // just photographed is still covering the editor and there is nothing
        // to type into. iPad keeps the editor beside the dock and offers no
        // Code chip at all, so this asks rather than assumes.
        if !editor.waitForExistence(timeout: 5) {
            let code = app.buttons["pane.code"]
            if app.scrollHorizontally(to: code) { code.tap() }
        }

        XCTAssertTrue(editor.waitForExistence(timeout: 30), "the workspace should still hold the file")

        // Below the last line of a seven-line file, which is where a text view
        // puts the caret when you tap past the end of its text.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        editor.typeText("\n\nfunc unusedExample() {\n    unusedTotal := 0\n}\n")

        // The keyboard covers the pane this is a screenshot of.
        let hide = app.buttons[AccessibilityIdentifier.hideKeyboard]
        if hide.waitForExistence(timeout: 5) { hide.tap() }

        runPhase("build")

        let problems = app.buttons["pane.problems"]
        XCTAssertTrue(app.scrollHorizontally(to: problems), "the Problems pane should be reachable")
        problems.tap()
        XCTAssertTrue(app.waitForSelection(of: problems), "Problems should become the selected pane")
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'unusedTotal'"))
                .element.waitForExistence(timeout: 60),
            "a build that cannot succeed should be reported in Problems"
        )
        capture("08-problems")
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

    /// Presses a build action and waits for it to finish.
    ///
    /// Finished means the progress strip has gone, not that the button was
    /// tapped — a screenshot taken a second after the tap is a screenshot of a
    /// spinner, and it would go into the listing looking deliberate.
    private func runPhase(_ phase: String) {
        let action = app.buttons["phase.\(phase)"]
        XCTAssertTrue(action.waitForExistence(timeout: 30), "the workspace should offer \(phase)")
        XCTAssertTrue(
            action.isEnabled,
            "\(phase) is disabled, which means no toolchain is staged — "
                + "run scripts/build_toolchain.sh before capturing the listing"
        )
        action.tap()

        // Polled on the action itself rather than on the progress strip. The
        // button is disabled for exactly as long as its phase is running, and
        // it is already bound here — re-querying the app inside the loop is
        // what a screenshot run does not need to do six hundred times.
        let deadline = Date().addingTimeInterval(buildTimeout)
        var finished = false
        while Date() < deadline {
            if action.isEnabled {
                finished = true
                break
            }
            _ = action.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(finished, "\(phase) did not finish within \(Int(buildTimeout))s")
    }

    /// Asserts the editor arrived and has the template's source in it.
    private func expectSource() {
        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 30), "opening a template should land in the editor")
        XCTAssertFalse(
            (editor.value as? String ?? "").isEmpty,
            "the editor should hold the template's source"
        )
    }

    private func openTemplate(_ id: String) {
        let create = app.buttons[AccessibilityIdentifier.newProject]
        XCTAssertTrue(app.waitForElement(create), "the dashboard should offer a way to start")
        create.tap()

        let template = app.buttons["template.\(id)"]
        XCTAssertTrue(template.waitForExistence(timeout: 30), "template \(id) should be offered")
        template.tap()
    }

    /// Named with a leading number so the files sort into listing order once
    /// they are exported.
    ///
    /// Waits before shooting. Existing is not the same as settled: every one of
    /// these screens animates something into place — a pane crossfading its
    /// empty state out, a chip's selection easing in — and `runPhase` returning
    /// means the work finished, not that the screen has caught up. One capture
    /// came back with the Output pane's "No problems" placeholder and its real
    /// result both half transparent, drawn on top of each other.
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1.5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
