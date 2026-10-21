import XCTest

@MainActor
final class InterviewPrepUITests: XCTestCase {
    func testTabRootsReclaimHeaderSpaceAndKeepDetailNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn", "-appearanceMode", "light"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20))
        area.buttons["Course"].tap()
        XCTAssertLessThan(area.frame.minY, 120, "The learning selector should use the former title space")
        XCTAssertFalse(app.navigationBars.firstMatch.isHittable)
        let course = XCTAttachment(screenshot: app.screenshot())
        course.name = "learn-without-duplicate-heading"; course.lifetime = .keepAlways; add(course)
        app.buttons["learn.continue"].tap()
        returnFromDetail(in: app)
        area.buttons["Interview"].tap()
        let interviewContinue = app.buttons["interview.continue"]
        XCTAssertTrue(interviewContinue.waitForExistence(timeout: 10))
        interviewContinue.tap()
        returnFromDetail(in: app)

        app.tabBars.buttons["Projects"].tap()
        let library = app.buttons["projects.library"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars.firstMatch.isHittable)
        let projects = XCTAttachment(screenshot: app.screenshot())
        projects.name = "projects-without-duplicate-heading"; projects.lifetime = .keepAlways; add(projects)
        library.tap()
        returnFromDetail(in: app)

        app.tabBars.buttons["Settings"].tap()
        let theme = app.segmentedControls["settings.appearance"]
        XCTAssertTrue(theme.waitForExistence(timeout: 10))
        XCTAssertLessThan(theme.frame.minY, 160)
        XCTAssertFalse(app.navigationBars.firstMatch.isHittable)
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "settings-without-duplicate-heading"; settings.lifetime = .keepAlways; add(settings)
        let notices = app.buttons["settings.acknowledgements"]
        XCTAssertTrue(app.waitForElement(notices, scrollingUpTo: 12)); notices.tap()
        returnFromDetail(in: app)
    }

    private func returnFromDetail(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Detail screens must retain their navigation and Back button")
        XCTAssertTrue(back.isHittable)
        back.tap()
    }

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
        library.name = "interview-shared-course-design"; library.lifetime = .keepAlways; add(library)
        algorithms.tap()
        let binary = app.buttons["interview.question.algorithms.binary-search"]
        XCTAssertTrue(app.waitForElement(binary, scrollingUpTo: 4))
        binary.tap()
        let next = app.buttons["algorithm.next"]
        XCTAssertTrue(app.waitForElement(next, scrollingUpTo: 8))
        next.tap()
        XCTAssertTrue(app.staticTexts["algorithm.step"].label.contains("Step 2"))
        while next.isEnabled { next.tap() }
        XCTAssertTrue(app.waitForElement(app.staticTexts["algorithm.result"], scrollingUpTo: 4))
        XCTAssertEqual(app.staticTexts["algorithm.result"].label, "Result: index 1")
        let trace = XCTAttachment(screenshot: app.screenshot())
        trace.name = "algorithm-binary-boundary"; trace.lifetime = .keepAlways; add(trace)
    }
    func testContinueReopensLastInterviewAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20))
        area.buttons["Interview"].tap()
        let guide = app.buttons["interview.question.language.values"]
        openFoundations(in: app)
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
        openFoundations(in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        let reveal = app.buttons["interview.prep.reveal"]
        XCTAssertTrue(app.waitForElement(reveal, scrollingUpTo: 8)); reveal.tap()
        let mark = app.buttons["Revisit"]
        XCTAssertTrue(app.waitForElement(mark, scrollingUpTo: 18)); mark.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(area.waitForExistence(timeout: 20)); area.buttons["Interview"].tap()
        let resume = app.buttons["interview.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10)); resume.tap()
        XCTAssertTrue(app.waitForElement(reveal, scrollingUpTo: 8)); reveal.tap()
        let status = app.staticTexts["interview.prep.status"]
        XCTAssertTrue(app.waitForElement(status, scrollingUpTo: 18))
        XCTAssertTrue(status.label.contains("revisit"))
        app.buttons["Clear"].tap()
        XCTAssertTrue(status.label.contains("not marked"))
    }

    func testCourseAndInterviewKeepTheSameHeaderAndTopicNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20))
        area.buttons["Course"].tap()
        let courseContinue = app.buttons["learn.continue"]
        XCTAssertTrue(courseContinue.waitForExistence(timeout: 10))
        let pickerFrame = area.frame
        let courseActionFrame = courseContinue.frame
        let course = XCTAttachment(screenshot: app.screenshot())
        course.name = "course-shared-design"; course.lifetime = .keepAlways; add(course)
        area.buttons["Interview"].tap()
        let interviewContinue = app.buttons["interview.continue"]
        XCTAssertTrue(interviewContinue.waitForExistence(timeout: 10))
        XCTAssertEqual(area.frame.minY, pickerFrame.minY, accuracy: 1)
        XCTAssertEqual(interviewContinue.frame.width, courseActionFrame.width, accuracy: 1)
        XCTAssertEqual(interviewContinue.frame.minY, courseActionFrame.minY, accuracy: 1)
        let interview = XCTAttachment(screenshot: app.screenshot())
        interview.name = "interview-shared-design"; interview.lifetime = .keepAlways; add(interview)
        openFoundations(in: app)
        let guide = app.buttons["interview.question.language.values"]
        XCTAssertTrue(guide.waitForExistence(timeout: 10))
        guide.tap()
        XCTAssertTrue(app.buttons["interview.prep.reveal"].waitForExistence(timeout: 10))
    }

    func testSearchFindsGuidesAndResetRestoresTopics() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 20)); area.buttons["Interview"].tap()
        let search = app.textFields["interview.search"]
        XCTAssertTrue(app.waitForElement(search, scrollingUpTo: 4))
        search.tap(); search.typeText("impossible-keyword-123\n")
        let empty = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'No Results for'")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        let reset = app.buttons["interview.resetFilters"]
        XCTAssertTrue(app.waitForElement(reset, scrollingUpTo: 3)); reset.tap()
        XCTAssertTrue(app.buttons["interview.topic.language"].waitForExistence(timeout: 10))
        search.tap(); search.typeText("Zero values\n")
        let guide = app.buttons["interview.question.language.values"]
        XCTAssertTrue(app.waitForElement(guide, scrollingUpTo: 4)); guide.tap()
        XCTAssertTrue(app.buttons["interview.prep.reveal"].waitForExistence(timeout: 10))
    }

    private func openFoundations(in app: XCUIApplication) {
        let topic = app.buttons["interview.topic.language"]
        XCTAssertTrue(app.waitForElement(topic, scrollingUpTo: 4))
        topic.tap()
    }
}
