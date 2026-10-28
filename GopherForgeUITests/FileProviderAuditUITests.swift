#if GOPHERFORGE_AUDIT_QA
import XCTest

@MainActor
final class FileProviderAuditUITests: XCTestCase {
    func testTwoFilesLibrariesKeepTheirOwnEditsAfterSwitchingAndProcessRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeAuditFixtures", "-GopherForgeSection", "projects"]
        app.launch()
        let markerA = "QA_A_SAVED_" + UUID().uuidString
        let markerB = "QA_B_SAVED_" + UUID().uuidString
        chooseLibrary("A", app: app)
        editProject("A", marker: markerA, app: app)
        restart(app)
        assertProject("A", contains: markerA, excludes: markerB, app: app)
        chooseLibrary("B", app: app)
        editProject("B", marker: markerB, app: app)
        restart(app)
        assertProject("B", contains: markerB, excludes: markerA, app: app)
        chooseLibrary("A", app: app)
        assertProject("A", contains: markerA, excludes: markerB, app: app)
        chooseLibrary("B", app: app)
        assertProject("B", contains: markerB, excludes: markerA, app: app)
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "separate-files-libraries-survive-relaunch"; proof.lifetime = .keepAlways; add(proof)
    }

    private func chooseLibrary(_ suffix: String, app: XCUIApplication) {
        let projects = app.sectionButton("Projects")
        XCTAssertTrue(projects.waitForExistence(timeout: 15)); projects.tap()
        let choose = app.buttons[AccessibilityIdentifier.keepLibraryInCloud]
        XCTAssertTrue(app.waitForElement(choose)); choose.tap()
        XCTAssertTrue(app.collectionViews["File View"].waitForExistence(timeout: 15))
        let browse = app.buttons["Browse"]
        if browse.exists && !browse.isSelected { browse.tap() }
        let name = "Audit-Library-" + suffix
        let folder = app.staticTexts[name].firstMatch
        let current = app.buttons[name + ", Actions Menu"]
        for _ in 0..<5 {
            if current.exists { break }
            if folder.waitForExistence(timeout: 3) {
                let cell = app.cells[name + ", Folder"]
                XCTAssertTrue(cell.exists)
                cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
                if !current.waitForExistence(timeout: 3) {
                    cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).doubleTap()
                }
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "selected-qa-folder-" + suffix; shot.lifetime = .keepAlways; add(shot)
                break
            }
            let qa = app.staticTexts["GopherForge Audit QA"].firstMatch
            if qa.exists { qa.tap(); continue }
            let back = app.buttons["BackButton"].firstMatch
            if back.exists { back.tap(); continue }
            let local = app.staticTexts["On My iPhone"].firstMatch
            if local.exists { local.tap(); continue }
            break
        }
        XCTAssertTrue(current.waitForExistence(timeout: 10), "Only the named disposable QA folder may be selected: " + app.debugDescription)
        app.buttons["Open"].tap()
        XCTAssertTrue(app.staticTexts["Audit Project " + suffix].firstMatch.waitForExistence(timeout: 15), app.debugDescription)
    }

    private func openEditor(_ suffix: String, app: XCUIApplication) -> XCUIElement {
        let projects = app.sectionButton("Projects")
        XCTAssertTrue(projects.waitForExistence(timeout: 15)); projects.tap()
        let project = app.staticTexts["Audit Project " + suffix].firstMatch
        XCTAssertTrue(app.waitForElement(project)); project.tap()
        let editor = app.textViews[AccessibilityIdentifier.editor].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 15), app.debugDescription)
        return editor
    }

    private func editProject(_ suffix: String, marker: String, app: XCUIApplication) {
        let editor = openEditor(suffix, app: app)
        XCTAssertTrue((editor.value as? String ?? "").contains("QA_" + suffix), "The selected library must load its own source")
        editor.tap(); editor.typeText("\n// " + marker + "\n")
        XCTAssertTrue((editor.value as? String ?? "").contains(marker))
    }

    private func assertProject(_ suffix: String, contains marker: String, excludes other: String, app: XCUIApplication) {
        let editor = openEditor(suffix, app: app)
        let source = editor.value as? String ?? ""
        XCTAssertTrue(source.contains(marker), "Saved source must survive bookmark restoration and process relaunch")
        XCTAssertFalse(source.contains(other), "Switching libraries must not substitute the other project's source")
    }

    private func restart(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        app.terminate(); app.launch()
    }

    func testInspectSystemFolderPickerInIsolatedQAApp() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-GopherForgeAuditFixtures"]
        app.launch()
        let projects = app.sectionButton("Projects")
        XCTAssertTrue(projects.waitForExistence(timeout: 20)); projects.tap()
        let choose = app.buttons[AccessibilityIdentifier.keepLibraryInCloud]
        XCTAssertTrue(app.waitForElement(choose)); choose.tap()
        _ = app.collectionViews["File View"].waitForExistence(timeout: 15)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = "system-folder-picker-tree"; tree.lifetime = .keepAlways; add(tree)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "system-folder-picker"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(app.collectionViews["File View"].exists && app.buttons["Open"].exists, "The system folder picker must open")
        if !app.buttons["Browse"].isSelected { app.buttons["Browse"].tap() }
        let browse = XCTAttachment(string: app.debugDescription); browse.name = "folder-picker-browse-tree"; browse.lifetime = .keepAlways; add(browse)
        let browseShot = XCTAttachment(screenshot: app.screenshot()); browseShot.name = "folder-picker-browse"; browseShot.lifetime = .keepAlways; add(browseShot)
        let fixture = app.staticTexts["Audit-Library-A"].firstMatch
        if !fixture.waitForExistence(timeout: 10) {
            let qaFolder = app.staticTexts["GopherForge Audit QA"].firstMatch
            XCTAssertTrue(qaFolder.waitForExistence(timeout: 15), "The isolated QA documents folder should be offered by Files")
            qaFolder.tap()
        }
        XCTAssertTrue(fixture.waitForExistence(timeout: 10)); fixture.tap()
        let open = app.buttons["Open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); XCTAssertTrue(open.isEnabled); open.tap()
        XCTAssertTrue(app.staticTexts["Audit Project A"].firstMatch.waitForExistence(timeout: 15), "Opening an existing folder must load its project, not import it as a source folder")
        let selected = XCTAttachment(string: app.debugDescription); selected.name = "library-a-selected-tree"; selected.lifetime = .keepAlways; add(selected)
    }
}
#endif
