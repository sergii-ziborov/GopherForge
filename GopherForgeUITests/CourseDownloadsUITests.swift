import XCTest

@MainActor
final class CourseDownloadsUITests: XCTestCase {
    func testDownloadedCoursesAndActualDevOpsShell() {
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeCourseFixtures"]
        app.launch()
        let downloads = app.buttons["learn.downloads"]
        XCTAssertTrue(downloads.waitForExistence(timeout: 25))
        downloads.tap()
        XCTAssertTrue(app.staticTexts["Go: language and services"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "course-downloads"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 10))
        area.buttons["DevOps"].tap()
        let lab = app.buttons["devops.lab.logs-pipeline"]
        XCTAssertTrue(lab.waitForExistence(timeout: 10))
        lab.tap()
        let run = app.buttons["devops.run"]
        if !run.isHittable { app.swipeUp() }
        XCTAssertTrue(run.waitForExistence(timeout: 10))
        run.tap()
        let checks = app.staticTexts["devops.checks"]
        XCTAssertTrue(checks.waitForExistence(timeout: 60))
        let predicate = NSPredicate(format: "label CONTAINS %@", "1 of 1")
        expectation(for: predicate, evaluatedWith: checks)
        waitForExpectations(timeout: 60)
        app.swipeUp()
        let labShot = XCTAttachment(screenshot: app.screenshot()); labShot.name = "devops-pipeline-result"; labShot.lifetime = .keepAlways; add(labShot)
    }
    func testExplicitPublicCourseDownloadAndRemoval() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeEmptyCourses"]
        app.launch()
        XCTAssertTrue(app.buttons["learn.downloads"].waitForExistence(timeout: 25))
        app.buttons["learn.downloads"].tap()
        let manage = app.buttons["courses.manage.devops"]
        let download = app.buttons["courses.download.devops"]
        for _ in 0..<4 where !manage.isHittable && !download.isHittable { app.swipeUp() }
        if manage.exists {
            manage.tap()
            app.buttons["Remove download"].tap()
            app.buttons["Remove DevOps and reliability"].tap()
        }
        XCTAssertTrue(download.waitForExistence(timeout: 10))
        XCTAssertFalse(manage.exists, "Opening the page must not install a course")
        let listed = XCTAttachment(screenshot: app.screenshot())
        listed.name = "course-not-downloaded"; listed.lifetime = .keepAlways; add(listed)
        // A course that is not downloaded is still shown where it lives, with
        // its own Download button.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.segmentedControls["learn.area"].buttons["DevOps"].tap()
        XCTAssertTrue(download.waitForExistence(timeout: 10))
        download.tap()
        XCTAssertTrue(app.buttons["devops.playground"].waitForExistence(timeout: 90), app.debugDescription)
        app.buttons["learn.downloads"].tap()
        XCTAssertTrue(manage.waitForExistence(timeout: 10))
        let downloaded = XCTAttachment(screenshot: app.screenshot())
        downloaded.name = "public-course-downloaded"; downloaded.lifetime = .keepAlways; add(downloaded)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["learn.downloads"].waitForExistence(timeout: 25))
        app.segmentedControls["learn.area"].buttons["DevOps"].tap()
        XCTAssertTrue(app.buttons["devops.playground"].waitForExistence(timeout: 10))
        app.buttons["devops.playground"].tap()
        let input = app.textFields["devops.terminal.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("pwd\n")
        XCTAssertTrue(output(in: app, startingWith: "/lab").waitForExistence(timeout: 60), app.debugDescription)
        let terminal = XCTAttachment(screenshot: app.screenshot())
        terminal.name = "terminal-playground-public-course"; terminal.lifetime = .keepAlways; add(terminal)
    }

    /// Reported from TestFlight 1.3.4 (57): after downloading dedicated
    /// courses on Learn, their cards said "Offline" but the course never
    /// became a path, so it could not be opened. Each course is downloaded
    /// from Learn in turn and must open at its first unit right away.
    func testDedicatedCoursesOpenRightAfterDownloadingOnLearn() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeEmptyCourses"]
        app.launch()
        let courses = [("blockchain", "blockchain-foundations", "blockchain.hash-chains"),
                       ("security", "security", "security.identity-authorization"),
                       ("gamedev", "gamedev-loop", "gamedev.fixed-timestep")]
        let titles = ["blockchain": "Blockchain infrastructure in Go", "security": "Secure Go services",
                      "gamedev": "Game development in Go"]
        XCTAssertTrue(app.buttons["learn.downloads"].waitForExistence(timeout: 25))
        app.buttons["learn.downloads"].tap()
        for (id, _, _) in courses {
            let manage = app.buttons["courses.manage.\(id)"]
            let download = app.buttons["courses.download.\(id)"]
            for _ in 0..<6 where !manage.isHittable && !download.isHittable { app.swipeUp() }
            if manage.exists {
                manage.tap()
                app.buttons["courses.remove.\(id)"].tap()
                app.buttons["Remove \(titles[id]!)"].tap()
            }
            XCTAssertTrue(download.waitForExistence(timeout: 10), id)
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.segmentedControls["learn.area"].buttons["Course"].tap()
        for (id, unitID, lessonID) in courses {
            let download = app.buttons["courses.download.\(id)"]
            XCTAssertTrue(app.waitForElement(download, scrollingUpTo: 40, timeout: 2), id)
            download.tap()
            let unit = app.buttons["unit.\(unitID)"]
            XCTAssertTrue(unit.waitForExistence(timeout: 90), "\(id) did not become a path: \(app.debugDescription)")
            XCTAssertFalse(download.exists, "\(id) still offers Download after installing")
            XCTAssertTrue(app.waitForElement(unit, scrollingUpTo: 10, timeout: 1), id)
            let opened = XCTAttachment(screenshot: app.screenshot())
            opened.name = "dedicated-\(id)-path"; opened.lifetime = .keepAlways; add(opened)
            unit.tap()
            let lesson = app.buttons["lesson.\(lessonID)"]
            XCTAssertTrue(app.waitForElement(lesson, scrollingUpTo: 5, timeout: 5), lessonID)
            lesson.tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
            app.navigationBars.buttons.firstMatch.tap()
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.segmentedControls["learn.area"].waitForExistence(timeout: 10))
        }
    }

    /// The playground is a terminal: one prompt, state that carries between
    /// lines, Tab completion, continuation lines and an editor.
    func testTerminalPlaygroundIsAnInteractiveShell() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeCourseFixtures"]
        app.launch()
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 25))
        area.buttons["DevOps"].tap()
        let playground = app.buttons["devops.playground"]
        XCTAssertTrue(playground.waitForExistence(timeout: 10))
        playground.tap()
        app.buttons["devops.menu"].tap()
        app.buttons["Reset playground…"].tap()
        app.buttons["Reset playground files"].tap()

        let input = app.textFields["devops.terminal.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("cd scr")
        app.buttons["devops.key.tab"].tap()
        XCTAssertEqual(input.value as? String, "cd scripts/")
        input.typeText("\n")
        input.typeText("for i in 1 2; do\n")
        input.typeText("echo item-$i\n")
        input.typeText("done\n")
        XCTAssertTrue(output(in: app, startingWith: "item-1").waitForExistence(timeout: 60), app.debugDescription)

        input.typeText("nano notes.txt\n")
        let editor = app.textViews["devops.editor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.typeText("deploy ok")
        app.buttons["devops.editor.save"].tap()
        XCTAssertTrue(output(in: app, startingWith: "Saved ~/scripts/notes.txt").waitForExistence(timeout: 10))
        input.tap()
        input.typeText("grep -c ok notes.txt && kubectl get pods\n")
        XCTAssertTrue(output(in: app, startingWith: "kubectl: unavailable here").waitForExistence(timeout: 60))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "terminal-playground-session"; shot.lifetime = .keepAlways; add(shot)
    }

    private func output(in app: XCUIApplication, startingWith text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "devops.output", text)).firstMatch
    }

}
