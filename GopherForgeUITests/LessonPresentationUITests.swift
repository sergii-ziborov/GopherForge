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

    func testEmbeddedCodeScrollsTheLessonAndExpandedEditsSurvive() throws {
        launch("core.multiple-returns")
        let expand = app.buttons["lesson.editor.expand"]
        XCTAssertTrue(app.waitForElement(expand, scrollingUpTo: 15))
        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch.frame
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        // A full-page swipe can already reach the bottom of this short
        // exercise. Move just enough to expose code before testing its pan.
        for _ in 0..<4 where editor.frame.intersection(window.insetBy(dx: 0, dy: 110)).height < 80 {
            origin.withOffset(CGVector(dx: window.width / 2, dy: window.height - 160))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: window.width / 2, dy: window.height - 250)))
        }
        let visibleEditor = editor.frame.intersection(window.insetBy(dx: 0, dy: 110))
        XCTAssertGreaterThan(visibleEditor.height, 40)
        let before = expand.frame.minY
        let startY = visibleEditor.maxY - 15
        print("Embedded pan: editor=\(editor.frame), visible=\(visibleEditor), headerY=\(before)")
        attachScreenshot(named: "lesson-before-embedded-pan")
        origin.withOffset(CGVector(dx: window.width / 2, dy: startY - window.minY))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: window.width / 2, dy: max(140, startY - 160) - window.minY)))
        attachScreenshot(named: "lesson-after-embedded-pan")
        XCTAssertLessThan(expand.frame.minY, before - 30, "Dragging embedded code must move the lesson page")
        // Return to the explicit expand control after the gesture above.
        app.swipeDown()
        XCTAssertTrue(app.waitForElement(expand, scrollingUpTo: 15))
        expand.tap()
        let collapse = app.buttons["lesson.editor.collapse"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 10))
        // A full-screen cover keeps the underlying page in the AX tree.
        // Choose the editor the user can interact with, rather than assuming
        // that the hidden embedded editor has already disappeared.
        let fullEditor = try XCTUnwrap(
            app.textViews.matching(identifier: AccessibilityIdentifier.editor)
                .allElementsBoundByIndex.first(where: { $0.isHittable })
        )
        fullEditor.tap()
        fullEditor.typeText("\n// retained after full screen\n")
        XCTAssertTrue((fullEditor.value as? String ?? "").contains("retained after full screen"))
        let closeY = collapse.frame.minY
        fullEditor.swipeUp()
        XCTAssertEqual(collapse.frame.minY, closeY, accuracy: 2, "Expanded scrolling must stay inside the code view")
        collapse.tap()
        XCTAssertTrue(collapse.waitForNonExistence(timeout: 10))
        XCTAssertTrue(expand.waitForExistence(timeout: 10))
        XCTAssertTrue((app.textViews[AccessibilityIdentifier.editor].value as? String ?? "").contains("retained after full screen"))
    }

    private func launch(_ id: String) {
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeLesson", id]
        app.launch()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
