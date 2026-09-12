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

    /// The phone once rendered a narrow file column underneath its Files
    /// drawer. The editor started halfway across the screen, and tapping Files
    /// opened a second copy of the tree. iPad should keep its single column.
    func testNavigatorOccupiesOnePlaceForTheDevice() {
        launch()

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        let files = app.buttons[AccessibilityIdentifier.filesToggle]
        let search = app.textFields[AccessibilityIdentifier.fileSearch]
        let goMod = app.buttons["file.go.mod"]

        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertFalse(files.exists, "iPad should not offer a button to open a second tree")
            XCTAssertTrue(search.waitForExistence(timeout: 5), "iPad should show its file tree")
            XCTAssertTrue(goMod.waitForExistence(timeout: 5))
            goMod.tap()
            XCTAssertTrue(search.exists, "choosing a file should leave the iPad tree in place")
        } else {
            XCTAssertTrue(files.waitForExistence(timeout: 5))
            XCTAssertFalse(search.exists, "the phone drawer should start closed")

            let window = app.windows.firstMatch.frame
            let initialEditor = editor.frame
            XCTAssertLessThan(
                initialEditor.minX, window.width * 0.15,
                "a phantom file column must not push the phone editor sideways"
            )
            XCTAssertGreaterThan(initialEditor.width, window.width * 0.7)

            files.tap()
            XCTAssertTrue(search.waitForExistence(timeout: 5), "Files should open the drawer")
            XCTAssertEqual(editor.frame.minX, initialEditor.minX, accuracy: 2)
            XCTAssertEqual(editor.frame.width, initialEditor.width, accuracy: 2)

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

    /// iPad shows the navigator beside the editor; iPhone keeps it behind the
    /// Files control. Open it whichever way this device offers.
    private func openNavigator() {
        let search = app.textFields[AccessibilityIdentifier.fileSearch]
        guard !search.waitForExistence(timeout: 6) else { return }

        let files = app.buttons[AccessibilityIdentifier.filesToggle]
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
