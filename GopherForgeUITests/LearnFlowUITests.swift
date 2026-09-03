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
            app.buttons["lesson.concurrency.channel-close"].waitForExistence(timeout: 10),
            "the unit should list its lessons"
        )
        attachScreenshot(named: "11-unit")
    }

    /// The defect this was written for: marking a lesson complete wrote to disk
    /// and changed nothing on screen. The unit list held the completed set it
    /// was built with, so progress only appeared after relaunching the app.
    ///
    /// Progress survives between runs, so the lesson is put into a known state
    /// first rather than assumed to be untouched.
    func testMarkingALessonCompleteShowsUpInTheUnit() {
        launch(arguments: ["-GopherForgeSection", "learn"])

        let unit = app.buttons["unit.concurrency"]
        XCTAssertTrue(app.waitForElement(unit))
        unit.tap()

        let row = app.buttons["lesson.concurrency.channel-close"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        // Back to not-done, if a previous run left it marked.
        let undo = app.buttons[AccessibilityIdentifier.lessonUncomplete]
        if undo.waitForExistence(timeout: 3) { undo.tap() }

        let mark = app.buttons[AccessibilityIdentifier.lessonComplete]
        XCTAssertTrue(
            app.waitForElement(mark),
            "every lesson should offer a way to say it has been done"
        )
        mark.tap()

        // The toolbar, not the card at the bottom: a compile lesson puts an
        // editor above the card, and a swipe over a text view scrolls the text.
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.lessonUncomplete].waitForExistence(timeout: 5),
            "the lesson should say it is done, from somewhere reachable"
        )

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(
            row.value as? String,
            "Marked done",
            "the unit should show the tick without the app being relaunched"
        )
        attachScreenshot(named: "11b-lesson-marked")
    }

    /// A prediction keeps its answer hidden until the learner commits.
    ///
    /// These live in Practice now rather than in the middle of a unit: a
    /// question with an answer is not the same thing as a lesson with something
    /// to build.
    func testAPredictionKeepsItsAnswerHiddenUntilAsked() {
        launch(arguments: ["-GopherForgeSection", "learn", "-GopherForgeScreen", "drills"])

        let challenge = app.buttons["practice.challenge.concurrency.unbuffered-rendezvous"]
        XCTAssertTrue(app.waitForElement(challenge), "practice should offer the prediction")
        challenge.tap()

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
        openFirstScenario()

        let run = app.buttons[AccessibilityIdentifier.labRun]
        // Waited for rather than asserted on the spot: the scenario screen is
        // pushed by the tap above, and under a full suite the push is not
        // finished by the next line.
        XCTAssertTrue(
            run.waitForExistence(timeout: 15),
            "the scenario screen should offer Run"
        )
        XCTAssertEqual(
            run.isEnabled, !isToolchainMissing,
            "the lab's Run should follow the toolchain, not a fixed expectation"
        )
        attachScreenshot(named: "13-lab")

        // Running the scenario for real does not belong here. This suite
        // deliberately excludes the expensive compiler gates, and a real Go
        // build under the interpreter takes longer than any timeout that is
        // honest in a smoke test — it passed on a warm cache and failed on a
        // cold one, which is a test measuring the cache. The timeline's own
        // geometry is covered by ConcurrencyTimelineLayoutTests, and an
        // end-to-end lab run belongs to the GopherForgeCompilerGate scheme.
    }

    func testLabPredictionStaysClosedUntilAsked() {
        launch(arguments: ["-GopherForgeSection", "learn", "-GopherForgeScreen", "lab"])
        openFirstScenario()

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

    /// The lab is a shelf now rather than a dropdown, so a scenario has to be
    /// opened before there is anything to run or predict.
    private func openFirstScenario() {
        let scenario = app.buttons[AccessibilityIdentifier.labScenario("unbuffered-rendezvous")]
        XCTAssertTrue(app.waitForElement(scenario), "the lab should offer its scenarios")
        scenario.tap()
    }

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
