import UIKit
import XCTest

/// The file navigator: a column on iPad, a drawer on iPhone, and a search that
/// looks inside files as well as at their names.
///
/// Separate from the workspace's own flows because it answers a different
/// question — how you find the file you want — and because the workspace file
/// was long enough that adding to it made both harder to read.
final class NavigatorFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// The navigator searches, by file name and by what is inside a file.
    ///
    /// Both halves matter: a name search that misses a content hit is only half
    /// a search, and a content hit that does not carry its line number is a
    /// result you still have to go and find.
    func testTheNavigatorSearchesNamesAndContents() {
        launch()
        openNavigator()

        let field = app.textFields[AccessibilityIdentifier.fileSearch]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the navigator should offer a search field")

        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.addPackage].waitForExistence(timeout: 5),
            "the navigator should offer to add a package without listing vendor files"
        )

        field.tap()
        field.typeText("go.mod")
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'search.name:'")
            ).firstMatch.waitForExistence(timeout: 5),
            "searching a file name should find the file"
        )

        clear(field)
        field.typeText("func main")
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'search.line:'")
            ).firstMatch.waitForExistence(timeout: 5),
            "searching a line of code should find the line"
        )
        attachScreenshot(named: "21-search")
    }

    func testCreateFolderAndFileFromTheNavigator() {
        launch()
        openNavigator()

        let add = app.buttons["files.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let folderAction = app.buttons["files.newFolder"]
        XCTAssertTrue(folderAction.waitForExistence(timeout: 5))
        folderAction.tap()
        let name = app.alerts.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("helpers")
        app.alerts.buttons["Create"].tap()

        add.tap()
        let fileAction = app.buttons["files.newFile"]
        XCTAssertTrue(fileAction.waitForExistence(timeout: 5))
        fileAction.tap()
        let fileName = app.alerts.textFields["Name"]
        XCTAssertTrue(fileName.waitForExistence(timeout: 5))
        fileName.tap()
        fileName.typeText("extra.go")
        app.alerts.buttons["Create"].tap()

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue((editor.value as? String ?? "").contains("package main"))
    }

    /// A file chosen while the terminal is showing still has to open in the
    /// editor. Leaving the pane where it was hid the file behind the console.
    func testChoosingAFileShowsTheCodeEvenFromTheTerminal() {
        launch()

        let terminal = app.buttons["pane.terminal"]
        if terminal.waitForExistence(timeout: 5) {
            XCTAssertTrue(app.selectWorkspacePane("terminal"))
        }

        openNavigator()
        let goMod = app.buttons["file.go.mod"]
        XCTAssertTrue(goMod.waitForExistence(timeout: 5), "go.mod should be listed in the tree")
        goMod.tap()

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "choosing a file should show the editor")
        XCTAssertTrue(
            (editor.value as? String ?? "").contains("module "),
            "the editor should hold the file that was chosen"
        )

        let code = app.buttons["pane.code"]
        if code.exists {
            XCTAssertTrue(code.isSelected, "the Code pane should become selected")
        }
    }

    func testFileTreeSwitchesTheOpenFile() {
        launch()

        openNavigator()
        let goMod = app.buttons["file.go.mod"]
        XCTAssertTrue(goMod.waitForExistence(timeout: 5), "go.mod should be listed in the tree")
        goMod.tap()

        let editor = app.textViews[AccessibilityIdentifier.editor]
        let contents = editor.value as? String ?? ""
        XCTAssertTrue(contents.contains("module "), "selecting go.mod should show the module file")
        attachScreenshot(named: "05-gomod")
    }

    /// A narrow window uses a drawer, a book posture shows a visible tree,
    /// and a laptop posture opens Files in its lower pane.
    func testNavigatorOccupiesOnePlaceForTheWindow() {
        launch()

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        let files = app.buttons[AccessibilityIdentifier.filesToggle]
        let laptopFiles = app.buttons["laptop.files"]
        let search = app.textFields[AccessibilityIdentifier.fileSearch]
        let goMod = app.buttons["file.go.mod"]

        if search.waitForExistence(timeout: 3) {
            XCTAssertFalse(files.exists, "a visible tree must not have a second Files button")
            XCTAssertTrue(goMod.waitForExistence(timeout: 5))
            attachScreenshot(named: "navigator-wide-persistent")
            goMod.tap()
            XCTAssertTrue(search.exists, "choosing a file should leave the tree in place")
        } else if laptopFiles.waitForExistence(timeout: 2) {
            XCTAssertFalse(files.exists, "the laptop layout uses its lower pane for Files")
            let initialEditor = editor.frame
            laptopFiles.tap()
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            XCTAssertGreaterThan(search.frame.minY, initialEditor.midY,
                                 "Files should appear below the editor, across the hinge")
            XCTAssertEqual(editor.frame.minY, initialEditor.minY, accuracy: 2,
                           "opening Files must not move the upper editor")
            XCTAssertEqual(editor.frame.height, initialEditor.height, accuracy: 2,
                           "opening Files must not resize the upper editor")
            goMod.tap()
            XCTAssertTrue(search.waitForNonExistence(timeout: 5))
            XCTAssertTrue((editor.value as? String ?? "").contains("module "))
        } else {
            XCTAssertTrue(files.waitForExistence(timeout: 5))
            XCTAssertFalse(search.exists, "the drawer should start closed")

            let window = app.windows.firstMatch.frame
            let initialEditor = editor.frame
            XCTAssertLessThan(
                initialEditor.minX, window.width * 0.15,
                "a phantom file column must not push the editor sideways"
            )
            XCTAssertGreaterThan(initialEditor.width, window.width * 0.7)
            attachScreenshot(named: "navigator-iphone-code")

            files.tap()
            XCTAssertTrue(search.waitForExistence(timeout: 5), "Files should open the drawer")
            XCTAssertEqual(editor.frame.minX, initialEditor.minX, accuracy: 2)
            XCTAssertEqual(editor.frame.width, initialEditor.width, accuracy: 2)
            attachScreenshot(named: "navigator-iphone-files")

            XCTAssertTrue(goMod.waitForExistence(timeout: 5))
            goMod.tap()
            XCTAssertTrue(search.waitForNonExistence(timeout: 5), "selecting a file should close the drawer")
            XCTAssertEqual(editor.frame.minX, initialEditor.minX, accuracy: 2)
        }
    }

    private func launch() {
        app.launchArguments = ["-GopherForgeSection", "build"]
        app.launch()
    }

    /// The navigator may be a visible column or a drawer in a narrow window.
    private func openNavigator() {
        let search = app.textFields[AccessibilityIdentifier.fileSearch]
        guard !search.waitForExistence(timeout: 6) else { return }

        let files = app.buttons["laptop.files"].exists
            ? app.buttons["laptop.files"]
            : app.buttons[AccessibilityIdentifier.filesToggle]
        XCTAssertTrue(
            files.waitForExistence(timeout: 5),
            "a layout with no visible navigator must offer a way to open one"
        )
        files.tap()
        XCTAssertTrue(
            search.waitForExistence(timeout: 5),
            "opening the navigator should show its search field"
        )
    }

    private func clear(_ field: XCUIElement) {
        field.tap()
        let existing = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
