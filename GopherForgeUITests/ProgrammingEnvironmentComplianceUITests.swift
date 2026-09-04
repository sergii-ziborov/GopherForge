import XCTest

/// The Developer Program License Agreement's rules for programming environments.
///
/// An app that lets someone write and run code has to keep the code itself
/// under 80% of the viewing area, and has to show a conspicuous indicator that
/// this is a programming environment. Those are contract terms rather than
/// review guidelines, so they are not something a reviewer might let pass —
/// and the iPhone layout is the one at risk, because there the editor is a
/// full-height tab rather than one pane of a split.
///
/// Measured rather than eyeballed: the chrome above and below the editor is a
/// few points either side of the limit, and "it looks like about three
/// quarters" is not a thing to submit on.
@MainActor
final class ProgrammingEnvironmentComplianceUITests: XCTestCase {
    private var app: XCUIApplication!

    /// The contract's number.
    private let maximumCodeShare = 0.80

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-GopherForgeSection", "build"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testTheEditorStaysUnderTheCodeShareLimit() {
        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 30), "the workspace should show the editor")

        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(screen.width * screen.height, 0, "the app should have a window")

        // Clipped to the window first. The editor scrolls horizontally — long
        // lines are not wrapped, on purpose — so its own frame is as wide as
        // the widest line and routinely reports more width than the device
        // has. What the agreement is about is the area a person is looking at,
        // which is the part of the editor actually on the screen.
        let visible = editor.frame.intersection(screen)
        let share = (visible.width * visible.height) / (screen.width * screen.height)
        XCTAssertLessThanOrEqual(
            share, maximumCodeShare,
            """
            the editor covers \(Int((share * 100).rounded()))% of the screen, and the \
            Developer Program License Agreement allows at most \
            \(Int(maximumCodeShare * 100))% for executable code. Give the chrome \
            around it more room — visible editor \(visible), screen \(screen).
            """
        )
    }

    /// The other half of the same clause: it has to be obvious that this is a
    /// programming environment, which the app says by keeping the project and
    /// its build actions on screen beside the code rather than behind a menu.
    func testThePageSaysItIsAProgrammingEnvironment() {
        XCTAssertTrue(
            app.buttons["phase.build"].waitForExistence(timeout: 30),
            "the build action should be visible alongside the editor"
        )
        for phase in ["build", "test", "run"] {
            XCTAssertTrue(
                app.buttons["phase.\(phase)"].exists,
                "\(phase) should be on screen, not hidden behind a menu"
            )
        }
    }
}
