import XCTest

@MainActor
final class CurriculumExpansionUITests: XCTestCase {
    func testGinAndBlockchainReadingsAreReachableAndContinueRestoresPlace() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20)); area.buttons["Course"].tap()
        for (unitID, lessonID) in [("gin", "gin.routing-middleware"), ("blockchain", "blockchain.packages")] {
            let unit = app.buttons["unit.\(unitID)"]
            XCTAssertTrue(app.waitForElement(unit, scrollingUpTo: 25, timeout: 1)); unit.tap()
            let lesson = app.buttons["lesson.\(lessonID)"]
            XCTAssertTrue(app.waitForElement(lesson, scrollingUpTo: 5, timeout: 1)); lesson.tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = "curriculum-\(unitID)"; image.lifetime = .keepAlways; add(image)
            if unitID == "blockchain" {
                app.terminate(); app.launch()
                XCTAssertTrue(area.waitForExistence(timeout: 20))
                let resume = app.buttons["learn.continue"]
                XCTAssertTrue(resume.waitForExistence(timeout: 10))
                XCTAssertTrue(resume.label.localizedCaseInsensitiveContains("blockchain"))
                resume.tap()
                XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
            } else {
                app.navigationBars.buttons.firstMatch.tap()
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
    }

    func testGinInterviewTopicReachesWorkedGuide() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20)); area.buttons["Interview"].tap()
        let topic = app.buttons["interview.topic.gin"]
        XCTAssertTrue(app.waitForElement(topic, scrollingUpTo: 25, timeout: 1)); topic.tap()
        let guide = app.buttons["interview.question.gin.middleware-flow"]
        XCTAssertTrue(app.waitForElement(guide, scrollingUpTo: 5, timeout: 1)); guide.tap()
        XCTAssertTrue(app.buttons["interview.prep.reveal"].waitForExistence(timeout: 10))
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "gin-interview-guide"; image.lifetime = .keepAlways; add(image)
    }
}
