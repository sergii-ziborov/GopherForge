import XCTest

/// Drives the Learn side and the Concurrency Lab.
final class LearnFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCourseListsEveryUnit() {
        launch(arguments: ["-GopherForgeSection", "learn"])

        let units = [
            "core", "collections", "interfaces", "errors",
            "modules", "concurrency", "stdlib",
        ]
        for unit in units {
            XCTAssertTrue(
                app.waitForElement(app.buttons["unit.\(unit)"]),
                "unit \(unit) should be listed"
            )
        }
        attachScreenshot(named: "10-learn")
    }

    func testOpeningAUnitShowsItsLessons() {
        launch(arguments: ["-GopherForgeSection", "learn"])

        let unit = app.buttons["unit.concurrency"]
        XCTAssertTrue(app.waitForElement(unit), "the course list should reach every unit")
        unit.tap()

        XCTAssertTrue(
            app.buttons["lesson.concurrency.unbuffered-rendezvous"].waitForExistence(timeout: 10),
            "the unit should list its lessons"
        )
        attachScreenshot(named: "11-unit")
    }

    func testOpeningALessonShowsItsTaskAndHidesTheAnswer() {
        launch(arguments: ["-GopherForgeSection", "learn"])

        let unit = app.buttons["unit.concurrency"]
        XCTAssertTrue(app.waitForElement(unit))
        unit.tap()
        let lesson = app.buttons["lesson.concurrency.unbuffered-rendezvous"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        lesson.tap()

        XCTAssertTrue(
            app.staticTexts["Show the answer"].waitForExistence(timeout: 10),
            "a prediction lesson should keep its answer behind a disclosure"
        )
        // The explanation itself discusses deadlock, so the assertion keys on
        // wording only the hidden answer uses.
        XCTAssertFalse(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS 'all goroutines are asleep'"))
                .element.exists,
            "the answer should not be visible before it is opened"
        )

        app.staticTexts["Show the answer"].tap()
        XCTAssertTrue(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS 'all goroutines are asleep'"))
                .element.waitForExistence(timeout: 5),
            "opening the disclosure should reveal the answer"
        )
        attachScreenshot(named: "12-lesson")
    }

    /// The lab compiles and runs real code, so Run is offered exactly when a
    /// compiler is staged — never as a button that can only fail, and never
    /// withheld once there is something behind it.
    func testLabRunsExactlyWhenTheToolchainIsThere() {
        launch(arguments: ["-GopherForgeSection", "learn", "-GopherForgeScreen", "lab"])

        let picker = app.buttons[AccessibilityIdentifier.labScenarioPicker]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "the lab should offer its scenarios")

        let run = app.buttons[AccessibilityIdentifier.labRun]
        XCTAssertTrue(run.exists)
        XCTAssertEqual(
            run.isEnabled, !isToolchainMissing,
            "the lab's Run should follow the toolchain, not a fixed expectation"
        )
        attachScreenshot(named: "13-lab")
    }

    func testLabPredictionStaysClosedUntilAsked() {
        launch(arguments: ["-GopherForgeSection", "learn", "-GopherForgeScreen", "lab"])

        let prediction = app.buttons[AccessibilityIdentifier.labPrediction]
        XCTAssertTrue(prediction.waitForExistence(timeout: 10))
        // The lesson only works if the learner commits to an answer first, so
        // the prediction is closed until they open it.
        XCTAssertFalse(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Both goroutines wait'")).element.exists
        )

        prediction.tap()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'wait'")).element
                .waitForExistence(timeout: 5),
            "opening the disclosure should reveal the prediction"
        )
        attachScreenshot(named: "14-lab-prediction")
    }

    func testSettingsReportsTheToolchainAndOffersTheTheme() {
        launch(arguments: ["-GopherForgeSection", "settings"])

        let status = app.element(withIdentifier: AccessibilityIdentifier.settingsToolchainStatus)
        XCTAssertTrue(status.waitForExistence(timeout: 10), "settings should report the toolchain")
        let reported = status.label + (status.value as? String ?? "")
        XCTAssertTrue(
            reported.contains("Toolchain missing") || reported.contains("Bundled Go"),
            "settings should name what is actually there, got: \(status.label)"
        )
        XCTAssertTrue(
            app.waitForElement(app.element(withIdentifier: AccessibilityIdentifier.settingsAppearance)),
            "settings should offer the theme"
        )
        attachScreenshot(named: "15-settings")
    }

    // MARK: - Helpers

    private func launch(arguments: [String]) {
        app.launchArguments = arguments
        app.launch()
    }

    /// Read from the app rather than assumed, because both states are real: a
    /// checkout that has run `scripts/build_toolchain.sh` has a compiler, and a
    /// machine with no Go does not.
    private var isToolchainMissing: Bool {
        app.staticTexts["Toolchain missing"].exists
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
