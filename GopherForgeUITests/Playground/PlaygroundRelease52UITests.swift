import XCTest

/// Native render/interaction evidence for the collaboration release. Run on
/// owned iPhone and iPad simulators; attachments are inspected before upload.
@MainActor final class PlaygroundRelease52UITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }
    private func launch(_ section: String = "projects", lesson: String? = nil, dark: Bool = false) {
        app.launchArguments = ["-GopherForgeSection", section, "-GopherForgeEmptyLibrary",
            "-appearanceMode", dark ? "dark" : "light", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let lesson { app.launchArguments += ["-GopherForgeLesson", lesson] }
        app.launch()
    }
    private func openPlayground() {
        launch()
        let entry = app.buttons["projects.playground"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15)); entry.tap()
        XCTAssertTrue(app.navigationBars["Playground"].waitForExistence(timeout: 10))
    }
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "52-" + name; image.lifetime = .keepAlways; add(image)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "52-" + name + "-hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        if name.contains("landscape") {
            print("GF_RELEASE_FRAME_READY: 52-" + name); fflush(stdout)
            Thread.sleep(forTimeInterval: 8)
            let frame = app.windows.firstMatch.frame
            XCTAssertGreaterThan(frame.width, frame.height, "Native window follows landscape orientation")
        }
    }
    private func reach(_ element: XCUIElement) {
        XCTAssertTrue(app.waitForElement(element, scrollingUpTo: 8, timeout: 2)); element.tap()
    }
    private func nickname(_ name: String) {
        let input = app.textFields["playground.nickname"]
        XCTAssertTrue(input.waitForExistence(timeout: 10)); input.tap()
        if let existing = input.value as? String, !existing.isEmpty, existing != "Nickname" {
            input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        input.typeText(name)
    }
    func testAEditorKeyboardToolsAndDebugger() {
        openPlayground()
        capture("local-portrait")
        let source = app.textViews.firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        source.tap()
        capture("editor-keyboard")
        let hide = app.buttons[AccessibilityIdentifier.hideKeyboard]
        if hide.waitForExistence(timeout: 4) { hide.tap() }
        else { app.swipeDown() }
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("local-landscape")
        XCUIDevice.shared.orientation = .portrait
        reach(app.buttons["Debug"])
        let resume = app.buttons["Continue"]
        XCTAssertTrue(app.waitForElement(resume, scrollingUpTo: 10, timeout: 45))
        capture("debug-paused")
        reach(app.buttons["playground.debug.stop"])
        let run = app.buttons["playground.run"]
        XCTAssertTrue(app.waitForElement(run, scrollingUpTo: 10, timeout: 20))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: run)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 20), .completed)
    }
    func testBNicknameSharingAndRemoteNamedCursor() throws {
        openPlayground()
        reach(app.buttons["Room & AI connection"])
        if app.buttons["Leave room, keep local draft"].exists { reach(app.buttons["Leave room, keep local draft"]) }
        reach(app.buttons["playground.create"])
        nickname("Alex native")
        capture("nickname-prompt")
        app.buttons["playground.nickname.continue"].tap()
        XCTAssertTrue(app.buttons["Close room"].waitForExistence(timeout: 30))
        capture("encrypted-room-controls")
        reach(app.buttons["Close room"])
        XCTAssertTrue(app.buttons["playground.create"].waitForExistence(timeout: 20))
        let raw = try XCTUnwrap(ProcessInfo.processInfo.environment["GF_RELEASE_ROOM_LINK"], "Supply an owned encrypted room from the release peer harness")
        let link = app.textFields["playground.link"]
        reach(link); link.typeText(raw)
        reach(app.buttons["Join room"])
        nickname("Alex native")
        app.buttons["playground.nickname.continue"].tap()
        XCTAssertTrue(app.buttons["Leave room, keep local draft"].waitForExistence(timeout: 30))
        reach(app.buttons["Room & AI connection"])
        let cursor = app.staticTexts["Sam Web's cursor"]
        XCTAssertTrue(cursor.waitForExistence(timeout: 15), app.debugDescription)
        capture("named-cursor-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("named-cursor-landscape")
        XCUIDevice.shared.orientation = .portrait
        let run = app.buttons["playground.run"]
        let reports = app.staticTexts.matching(NSPredicate(format: "label == %@", "Alex native · run · Succeeded"))
        let previousReports = reports.count
        reach(run)
        // A warm cached run may finish before XCTest can observe a disabled
        // button. Require a newly published result, not a transient spinner.
        XCTAssertTrue(reports.element(boundBy: previousReports).waitForExistence(timeout: 60))
        let output = app.staticTexts["playground.localOutput"]
        XCTAssertTrue(app.waitForElement(output, scrollingUpTo: 12, timeout: 60))
        XCTAssertTrue(output.label.contains("Hello, shared Go"), output.label)
        capture("shared-local-output")
        // Scroll the outer page from its trailing gutter. A gesture through
        // the middle of the nested source/output editor can scroll that
        // editor instead, especially on a tall phone after viewing Output.
        let controls = app.buttons["Room & AI connection"]
        for _ in 0..<12 {
            if app.isOnScreen(controls) { break }
            let window = app.windows.firstMatch
            let frame = window.frame
            let origin = window.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: frame.width - 8, dy: 180))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(
                    CGVector(dx: frame.width - 8, dy: frame.height - 160)))
        }
        reach(app.buttons["Room & AI connection"])
        reach(app.buttons["Leave room, keep local draft"])
    }
    func testDCourseOverview() {
        app.launchArguments = ["-GopherForgeSection", "learn", "-learning.lastArea.v1", "0",
            "-appearanceMode", "light", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["unit.core"].waitForExistence(timeout: 20))
        capture("course-overview")
    }
    func testCDevOpsReadingAndDarkAppearance() {
        launch("learn", lesson: "devops.delivery-loop")
        XCTAssertTrue(app.element(withIdentifier: "reading.designGuide").firstMatch.waitForExistence(timeout: 20))
        capture("devops-reading")
        app.terminate()
        launch("learn", lesson: "devops.slo-burn", dark: true)
        XCTAssertTrue(app.element(withIdentifier: "reading.designGuide").firstMatch.waitForExistence(timeout: 20))
        capture("devops-dark")
    }
    func testFDevOpsCapstoneReading() {
        launch("learn", lesson: "devops.delivery-loop")
        let heading = app.staticTexts["Run the capstone model"].firstMatch
        XCTAssertTrue(app.waitForElement(heading, scrollingUpTo: 18, timeout: 20))
        capture("53-devops-capstone")
        let finalHeading = app.staticTexts["Finish the capstone with evidence"].firstMatch
        XCTAssertTrue(app.waitForElement(finalHeading, scrollingUpTo: 30, timeout: 10))
        capture("53-devops-capstone-acceptance")
    }
    func testERootScreensAndWorkspace() {
        launch()
        XCTAssertTrue(app.buttons["projects.playground"].waitForExistence(timeout: 20))
        capture("projects-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("projects-landscape")
        XCUIDevice.shared.orientation = .portrait
        reach(app.buttons[AccessibilityIdentifier.newProject])
        let template = app.buttons["template.worker-pool"]
        XCTAssertTrue(template.waitForExistence(timeout: 30)); template.tap()
        let create = app.buttons[AccessibilityIdentifier.newProjectCreate]
        XCTAssertTrue(create.waitForExistence(timeout: 15)); create.tap()
        XCTAssertTrue(app.textViews[AccessibilityIdentifier.editor].waitForExistence(timeout: 30))
        capture("workspace-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("workspace-landscape")
        launch("settings", dark: true)
        XCTAssertTrue(app.segmentedControls["settings.appearance"].waitForExistence(timeout: 20))
        capture("settings-landscape")
        XCUIDevice.shared.orientation = .portrait
        capture("settings-portrait")
    }
}
