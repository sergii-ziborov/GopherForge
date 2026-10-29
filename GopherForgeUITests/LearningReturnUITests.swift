import XCTest

@MainActor
final class LearningReturnUITests: XCTestCase {
    private func launchLearn(_ app: XCUIApplication) {
        app.launchArguments = ["-GopherForgeEmptyLibrary"]
        app.launch()
        let learn = app.sectionButton("Learn")
        XCTAssertTrue(learn.waitForExistence(timeout: 15)); learn.tap()
        if app.buttons["Course"].exists { app.buttons["Course"].tap() }
    }
    func testPracticeAndLabAreReachableThroughOrdinaryVisibleNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication(); launchLearn(app)
        let practice = app.buttons["learn.practiceLibrary"]
        XCTAssertTrue(app.waitForElement(practice)); practice.tap()
        let lab = app.buttons["practice.library.lab"]
        XCTAssertTrue(lab.waitForExistence(timeout: 10)); lab.tap()
        XCTAssertTrue(app.navigationBars["Concurrency Lab"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "practice-normal-route-lab"; shot.lifetime = .keepAlways; add(shot)
    }
    func testOwnLessonCodeSurvivesProcessRelaunchAndContinue() {
        continueAfterFailure = false
        let app = XCUIApplication(); launchLearn(app)
        let unit = app.buttons["unit.core"]
        XCTAssertTrue(app.waitForElement(unit)); unit.tap()
        let lesson = app.buttons["lesson.core.switch"]
        XCTAssertTrue(app.waitForElement(lesson)); lesson.tap()
        let expand = app.buttons["lesson.editor.expand"]
        XCTAssertTrue(app.waitForElement(expand), "the lesson should expose its full-screen editor")
        expand.tap()
        let editor = app.textViews["workspace.editor"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        let marker = "draft-relaunch-" + UUID().uuidString
        editor.typeText("\n// " + marker + "\n")
        XCTAssertTrue((editor.value as? String)?.contains(marker) == true)
        // Exercise the normal background save before terminating the process.
        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        app.terminate(); launchLearn(app)
        let resume = app.buttons["learn.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 15)); resume.tap()
        let expandAgain = app.buttons["lesson.editor.expand"]
        XCTAssertTrue(app.waitForElement(expandAgain), "Continue should reopen the code lesson")
        expandAgain.tap()
        let restored = app.textViews["workspace.editor"].firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertTrue((restored.value as? String)?.contains(marker) == true, "Continue must restore the learner’s source, not the starter")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "draft-restored-after-relaunch"; shot.lifetime = .keepAlways; add(shot)
    }
}
