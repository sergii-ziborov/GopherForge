import XCTest

@MainActor
final class LessonPresentationUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testDiagramAndPracticalNotesAreVisible() {
        launch("generics.constraints")
        XCTAssertTrue(app.element(withIdentifier: "lesson.diagram.generics.constraints").firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.waitForElement(app.element(withIdentifier: "lesson.practical").firstMatch, scrollingUpTo: 12))
        XCTAssertTrue(app.waitForElement(app.element(withIdentifier: "lesson.watchOut").firstMatch, scrollingUpTo: 12))
    }

    func testEmbeddedCodeScrollsTheLessonAndExpandedEditsSurvive() {
        launch("core.multiple-returns")
        let expand = app.buttons["lesson.editor.expand"]
        XCTAssertTrue(app.waitForElement(expand, scrollingUpTo: 15))
        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        // Bring the code body into the middle of the usable screen.
        app.scrollViews["lesson.page"].swipeUp(velocity: .slow)
        let before = expand.frame.minY
        let window = app.windows.firstMatch.frame
        let startY = min(max(editor.frame.minY + 80, 260), window.maxY - 180)
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: window.width / 2, dy: startY - window.minY))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: window.width / 2, dy: max(140, startY - 160) - window.minY)))
        XCTAssertLessThan(expand.frame.minY, before - 30, "Dragging embedded code must move the lesson page")
        // Return to the explicit expand control after the gesture above.
        app.swipeDown()
        XCTAssertTrue(app.waitForElement(expand, scrollingUpTo: 15))
        expand.tap()
        let collapse = app.buttons["lesson.editor.collapse"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 10))
        let fullEditor = app.textViews[AccessibilityIdentifier.editor]
        fullEditor.tap()
        fullEditor.typeText("\n// retained after full screen\n")
        XCTAssertTrue((fullEditor.value as? String ?? "").contains("retained after full screen"))
        let closeY = collapse.frame.minY
        fullEditor.swipeUp()
        XCTAssertEqual(collapse.frame.minY, closeY, accuracy: 2, "Expanded scrolling must stay inside the code view")
        collapse.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 10))
        XCTAssertTrue((app.textViews[AccessibilityIdentifier.editor].value as? String ?? "").contains("retained after full screen"))
    }

    private func launch(_ id: String) {
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeLesson", id]
        app.launch()
    }
}
