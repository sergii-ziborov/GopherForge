import XCTest

@MainActor
final class SitePreviewFlowUITests: XCTestCase {
    private let app = XCUIApplication()

    func testReactPreviewBuildsDirectlyFromOutputAndOffersProjectSharing() {
        app.launchArguments = ["-GopherForgeSection", "projects", "-GopherForgeEmptyLibrary"]
        app.launch()
        let examples = app.buttons[AccessibilityIdentifier.projectsExamples]
        XCTAssertTrue(examples.waitForExistence(timeout: 10)); examples.tap()
        let board = app.buttons["example.site.react-offline"]
        for _ in 0..<8 where !board.isHittable { app.swipeUp() }
        XCTAssertTrue(board.isHittable); board.tap()
        let open = app.buttons[AccessibilityIdentifier.exampleOpen]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        // Reproduce the reported state: successful Go output but no React build.
        let run = app.buttons["phase.run"]
        XCTAssertTrue(run.waitForExistence(timeout: 15))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: run)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        run.tap()
        XCTAssertTrue(app.selectWorkspacePane("output"))
        let build = app.buttons["output.buildPreview"]
        XCTAssertTrue(build.waitForExistence(timeout: 150), app.debugDescription)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Checking Gin routes'")).firstMatch.exists)
        attachScreenshot(named: "react-output-build-action-after-go-run")
        build.tap()
        let heading = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'understanding.'")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 90), app.debugDescription)
        XCTAssertFalse(build.exists)
        app.buttons["preview.actions"].tap()
        XCTAssertTrue(app.buttons["preview.shareProject"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["preview.externalBrowser"].exists, "An isolated custom origin cannot be opened by Safari")
        // Dismiss the menu without invoking a share recipient.
        app.tap()
        app.buttons["preview.fullscreen"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15))
        let add = app.webViews.buttons["Add task"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        attachScreenshot(named: "output-one-tap-react-preview")
        app.buttons["Done"].tap()
    }

    func testStaticSiteOffersTheActualBrowserAddressAndSharingActions() {
        app.launchArguments = ["-GopherForgeSection", "projects", "-GopherForgeEmptyLibrary"]
        app.launch()
        let examples = app.buttons[AccessibilityIdentifier.projectsExamples]
        XCTAssertTrue(examples.waitForExistence(timeout: 10)); examples.tap()
        let cafe = app.buttons["example.site.cafe"]
        for _ in 0..<8 where !cafe.isHittable { app.swipeUp() }
        XCTAssertTrue(cafe.isHittable); cafe.tap()
        let open = app.buttons[AccessibilityIdentifier.exampleOpen]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        XCTAssertTrue(app.selectWorkspacePane("output"))
        let run = app.buttons["phase.run"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: run)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        run.tap()
        let address = app.staticTexts[AccessibilityIdentifier.outputSite]
        XCTAssertTrue(address.waitForExistence(timeout: 150), app.debugDescription)
        XCTAssertTrue(address.label.hasPrefix("http://127.0.0.1:"))
        app.buttons["preview.actions"].tap()
        XCTAssertTrue(app.buttons["preview.externalBrowser"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["preview.shareLocalAddress"].exists)
        XCTAssertTrue(app.buttons["preview.shareProject"].exists)
        attachScreenshot(named: "static-preview-browser-and-share-actions")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
