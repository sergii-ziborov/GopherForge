import XCTest

/// The practice side: drills, achievements and the example library.
///
/// The drill board carries a promise a unit test cannot check — that every tile
/// is the same height and none of them move — so it is measured here, on the
/// real thing.
final class PracticeFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testADrillBoardOffersBothSidesToConnect() {
        launch(screen: "drills")

        let drill = app.buttons["drill.drill.concurrency"]
        XCTAssertTrue(app.waitForElement(drill), "the drills list should offer the concurrency drill")
        drill.tap()

        XCTAssertTrue(
            app.buttons["drill.tile.conc.close#prompt"].waitForExistence(timeout: 10),
            "the board should appear with both sides addressable"
        )
        XCTAssertTrue(app.buttons["drill.tile.conc.close#answer"].exists)
        attachScreenshot(named: "16-drill")
    }

    /// The whole reason the board is playable with a thumb: nothing changes
    /// size, so the tile you are reaching for stays where it was.
    func testEveryTileOnABoardIsTheSameHeight() {
        launch(screen: "drills")

        let drill = app.buttons["drill.drill.errors"]
        XCTAssertTrue(app.waitForElement(drill))
        drill.tap()

        let tiles = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'drill.tile.'")
        )
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(tiles.count, 4, "a drill should show both sides")

        let heights = Set((0..<tiles.count).map { tiles.element(boundBy: $0).frame.height })
        XCTAssertEqual(heights.count, 1, "tiles differ in height: \(heights.sorted())")
    }

    /// Connecting the right pair must not remove the tiles, because a row that
    /// disappears moves everything under it.
    func testAMatchedPairStaysOnTheBoard() {
        launch(screen: "drills")

        let drill = app.buttons["drill.drill.errors"]
        XCTAssertTrue(app.waitForElement(drill))
        drill.tap()

        let tiles = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'drill.tile.'")
        )
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
        let before = tiles.count

        let prompt = app.buttons["drill.tile.errors.wrap#prompt"]
        let answer = app.buttons["drill.tile.errors.wrap#answer"]
        XCTAssertTrue(prompt.exists && answer.exists)
        prompt.tap()
        answer.tap()

        XCTAssertEqual(tiles.count, before, "a matched pair should stay put, not vanish")
    }

    func testAchievementsShowWhatIsLeftRatherThanHidingIt() {
        launch(screen: "achievements")

        XCTAssertTrue(
            app.waitForElement(app.element(withIdentifier: "achievement.first.build")),
            "every badge should be listed, earned or not"
        )
        XCTAssertTrue(
            app.waitForElement(app.element(withIdentifier: "achievement.repaired")),
            "a locked badge is listed too, with what is left of it"
        )
        attachScreenshot(named: "17-achievements")
    }

    func testTheExampleLibraryShowsCodeAndItsOutput() {
        launch(screen: "examples")

        let example = app.buttons["example.conc.waitgroup"]
        XCTAssertTrue(app.waitForElement(example), "the library should list its examples")
        example.tap()

        XCTAssertTrue(
            app.staticTexts["Output"].waitForExistence(timeout: 10),
            "an example should show what it prints"
        )
        XCTAssertTrue(app.buttons[AccessibilityIdentifier.exampleOpen].exists)
        attachScreenshot(named: "18-example")
    }

    /// A quiz answers, explains, and only then moves on.
    func testAQuizExplainsBeforeItMovesOn() {
        launch(screen: "course")

        let unit = app.buttons["unit.errors"]
        XCTAssertTrue(app.waitForElement(unit))
        unit.tap()

        let quiz = app.buttons[AccessibilityIdentifier.quizEntry]
        XCTAssertTrue(app.waitForElement(quiz), "a unit should offer its quiz")
        quiz.tap()

        let firstOption = app.buttons["quiz.option.0"]
        XCTAssertTrue(firstOption.waitForExistence(timeout: 10), "the quiz should show its options")

        let continueButton = app.buttons[AccessibilityIdentifier.quizContinue]
        XCTAssertFalse(continueButton.exists, "there is nothing to continue to before answering")

        firstOption.tap()
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 5),
            "answering should explain and offer the next question"
        )
        attachScreenshot(named: "19-quiz")

        continueButton.tap()
        XCTAssertTrue(
            app.buttons["quiz.option.0"].waitForExistence(timeout: 5),
            "continuing should show the next question"
        )
    }

    /// Answering every question ends on a score, and the score is reachable.
    func testAQuizEndsOnAScore() {
        launch(screen: "course")

        let unit = app.buttons["unit.interfaces"]
        XCTAssertTrue(app.waitForElement(unit))
        unit.tap()
        let quiz = app.buttons[AccessibilityIdentifier.quizEntry]
        XCTAssertTrue(app.waitForElement(quiz))
        quiz.tap()

        let summary = app.otherElements[AccessibilityIdentifier.quizSummary]
        for _ in 0..<12 {
            if summary.exists || app.buttons[AccessibilityIdentifier.quizRestart].exists { break }
            let option = app.buttons["quiz.option.0"]
            guard option.waitForExistence(timeout: 5) else { break }
            option.tap()
            let next = app.buttons[AccessibilityIdentifier.quizContinue]
            guard next.waitForExistence(timeout: 5) else { break }
            next.tap()
        }

        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.quizRestart].waitForExistence(timeout: 10),
            "the quiz should end on a result with a way to try again"
        )
        attachScreenshot(named: "20-quiz-score")
    }

    // MARK: - Helpers

    private func launch(screen: String) {
        // "course" means the Learn list itself: the units are there, and a
        // quiz is reached through the unit it closes.
        app.launchArguments = screen == "course"
            ? ["-GopherForgeSection", "learn"]
            : ["-GopherForgeSection", "learn", "-GopherForgeScreen", screen]
        app.launch()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
