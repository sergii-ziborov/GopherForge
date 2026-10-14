import XCTest

@MainActor
final class PracticeFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws { app = nil }

    func testCompletingOneLessonPopulatesMatchingWithoutRelaunching() {
        resetProgress()
        completeShortDeclaration()
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.buttons["lesson.core.short-declaration"].waitForExistence(timeout: 10))
        app.buttons["BackButton"].tap()
        let review = app.buttons[AccessibilityIdentifier.reviewEntry]
        XCTAssertTrue(app.waitForElement(review))
        review.tap()
        XCTAssertTrue(app.buttons["drill.tile.review.core.short#prompt"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["drill.tile.review.core.assignment#answer"].exists)
        XCTAssertFalse(app.element(withIdentifier: "learn.review.empty").exists)
        attachScreenshot(named: "review-after-one-lesson")
    }

    func testEveryMatchingTileKeepsItsHeightAndACompletedPairStaysVisible() {
        resetProgress()
        completeShortDeclaration()
        launch(screen: "review")
        let prompt = app.buttons["drill.tile.review.core.short#prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'drill.tile.'"))
        XCTAssertEqual(tiles.count, 4)
        let heights = (0..<tiles.count).map { tiles.element(boundBy: $0).frame.height }
        XCTAssertLessThan((heights.max() ?? 0) - (heights.min() ?? 0), 0.5)
        prompt.tap()
        app.buttons["drill.tile.review.core.short#answer"].tap()
        XCTAssertEqual(tiles.count, 4)
    }

    func testWrongAnswerExplainsAndPersistsThenCorrectAnswerMovesForward() {
        resetProgress()
        launch(screen: "drills")
        app.buttons["practice.start"].tap()
        XCTAssertTrue(app.staticTexts["mistakes.question"].waitForExistence(timeout: 10))
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mistakes.option.'"))
        XCTAssertEqual(options.count, 3)
        let firstQuestion = app.staticTexts["mistakes.question"].label
        // The authored first question asks where count := 0 can appear.
        app.buttons["mistakes.option.1"].tap()
        XCTAssertTrue(app.element(withIdentifier: "mistakes.explanation").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["mistakes.question"].label, firstQuestion)
        attachScreenshot(named: "mistake-explanation-three-options")

        app.terminate()
        launch(screen: "drills")
        XCTAssertTrue(app.buttons["mistakes.start"].waitForExistence(timeout: 10), "the unfinished mistake must survive a relaunch")
        app.buttons["mistakes.start"].tap()
        XCTAssertTrue(app.staticTexts["mistakes.question"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["mistakes.question"].label, firstQuestion)
        app.buttons["mistakes.option.0"].tap()
        XCTAssertTrue(app.buttons["mistakes.done"].waitForExistence(timeout: 10), "one corrected concept should finish the run")
        app.buttons["mistakes.done"].tap()
        XCTAssertTrue(app.buttons["practice.start"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["mistakes.start"].exists, "the corrected mistake must leave the queue")

        app.terminate()
        launch(screen: "drills")
        XCTAssertFalse(app.buttons["mistakes.start"].exists)
        app.buttons["practice.start"].tap()
        XCTAssertTrue(app.staticTexts["mistakes.question"].waitForExistence(timeout: 10))
        XCTAssertNotEqual(app.staticTexts["mistakes.question"].label, firstQuestion, "the next check should continue past the saved answer")
        attachScreenshot(named: "mistake-cleared-next-question")

        launch(screen: "review")
        XCTAssertTrue(app.buttons["drill.tile.review.core.short#prompt"].waitForExistence(timeout: 10),
                      "the correctly answered concept should fill matching without a lesson tick")
        attachScreenshot(named: "review-from-correct-answer")
    }

    func testCorrectKnowledgeAnswerImmediatelyOpensTheNextQuestion() {
        resetProgress()
        launch(screen: "drills")
        app.buttons["practice.start"].tap()
        let first = app.staticTexts["mistakes.question"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let text = first.label
        app.buttons["mistakes.option.0"].tap()
        let changed = NSPredicate(format: "exists == true AND label != %@", text)
        expectation(for: changed, evaluatedWith: first)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.element(withIdentifier: "mistakes.explanation").exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mistakes.option.'")).count, 3)
    }

    func testAchievementsStillShowTheEarnedProgress() {
        launch(screen: "achievements")
        let badges = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'achievement.'"))
        XCTAssertTrue(badges.firstMatch.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(badges.count, 5)
    }

    func testTheExampleLibraryShowsCodeAndOutput() {
        launch(screen: "examples")
        let example = app.buttons["example.conc.waitgroup"]
        XCTAssertTrue(app.waitForElement(example))
        example.tap()
        XCTAssertTrue(app.staticTexts["Output"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[AccessibilityIdentifier.exampleOpen].exists)
    }

    private func resetProgress() {
        app.launchArguments = ["-GopherForgeSection", "settings"]
        app.launch()
        let reset = app.buttons["settings.resetProgress"]
        XCTAssertTrue(app.waitForElement(reset))
        reset.tap()
        let confirm = app.buttons["Reset everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        // Navigate to Learn before terminating so its refresh observes the
        // reset, rather than killing an asynchronous disk write mid-flight.
        app.sectionButton("Learn").tap()
        XCTAssertTrue(app.buttons["learn.continue"].waitForExistence(timeout: 10))
    }

    private func completeShortDeclaration() {
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let unit = app.buttons["unit.core"]
        XCTAssertTrue(app.waitForElement(unit))
        unit.tap()
        let lesson = app.buttons["lesson.core.short-declaration"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        lesson.tap()
        let done = app.buttons[AccessibilityIdentifier.lessonComplete]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        XCTAssertTrue(app.buttons[AccessibilityIdentifier.lessonUncomplete].waitForExistence(timeout: 5))
    }

    private func launch(screen: String) {
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeScreen", screen]
        app.launch()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
