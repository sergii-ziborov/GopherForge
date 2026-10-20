import XCTest

@MainActor
final class InterviewPrepUITests: XCTestCase {
    func testInterviewAreaOpensAndStepsThroughBoundaryCases() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20))
        area.buttons["Interview"].tap()
        let algorithms = app.buttons["interview.algorithms"]
        XCTAssertTrue(algorithms.waitForExistence(timeout: 10))
        let library = XCTAttachment(screenshot: app.screenshot())
        library.name = "interview-library-build39"; library.lifetime = .keepAlways; add(library)
        algorithms.tap()
        app.buttons["Binary search as a boundary invariant"].tap()
        let next = app.buttons["algorithm.next"]
        XCTAssertTrue(app.waitForElement(next, scrollingUpTo: 8))
        next.tap()
        XCTAssertTrue(app.staticTexts["algorithm.step"].label.contains("Step 2"))
        while next.isEnabled { next.tap() }
        XCTAssertTrue(app.waitForElement(app.staticTexts["algorithm.result"], scrollingUpTo: 4))
        XCTAssertEqual(app.staticTexts["algorithm.result"].label, "Result: index 1")
        let trace = XCTAttachment(screenshot: app.screenshot())
        trace.name = "algorithm-binary-boundary-build39"; trace.lifetime = .keepAlways; add(trace)
    }
    func testContinueReopensLastInterviewAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20))
        area.buttons["Interview"].tap()
        let guide = app.buttons["interview.question.language.values"]
        // The first row can straddle the bottom edge beneath the resume card.
        // XCTest scrolls it into view when tapped; a full-page search gesture
        // can skip that row and then continue away from it in the lazy list.
        XCTAssertTrue(guide.waitForExistence(timeout: 10))
        guide.tap()
        XCTAssertTrue(app.buttons["interview.prep.reveal"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(area.waitForExistence(timeout: 20))
        XCTAssertTrue(area.buttons["Interview"].isSelected)
        let resume = app.buttons["interview.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        let savedPlace = XCTAttachment(screenshot: app.screenshot())
        savedPlace.name = "interview-continue-after-relaunch"
        savedPlace.lifetime = .keepAlways
        add(savedPlace)
        resume.tap()
        XCTAssertTrue(app.buttons["interview.prep.reveal"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Zero values and safe APIs"].exists)
    }

    func testInterviewSelfAssessmentPersistsSeparatelyFromLessons() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20)); area.buttons["Interview"].tap()
        let card = app.buttons["interview.question.language.values"]
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        let reveal = app.buttons["interview.prep.reveal"]
        XCTAssertTrue(app.waitForElement(reveal, scrollingUpTo: 8)); reveal.tap()
        let mark = app.buttons["Revisit"]
        XCTAssertTrue(app.waitForElement(mark, scrollingUpTo: 18)); mark.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(area.waitForExistence(timeout: 20)); area.buttons["Interview"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        XCTAssertTrue(app.waitForElement(reveal, scrollingUpTo: 8)); reveal.tap()
        let status = app.staticTexts["interview.prep.status"]
        XCTAssertTrue(app.waitForElement(status, scrollingUpTo: 18))
        XCTAssertTrue(status.label.contains("revisit"))
        app.buttons["Clear"].tap()
        XCTAssertTrue(status.label.contains("not marked"))
    }
}
