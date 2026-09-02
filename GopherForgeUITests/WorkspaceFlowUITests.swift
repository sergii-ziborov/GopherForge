import XCTest

/// Drives the real app in the Simulator.
///
/// These cover what a unit test cannot: that a tap on a template actually lands
/// the user in the editor, that typing reaches the buffer, that the dock
/// switches, and that nothing offers an action the toolchain cannot honour.
/// Every element is addressed by identifier rather than by visible text.
final class WorkspaceFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Launched with an empty library on purpose. The landing screen only
    /// introduces the product when there is nothing to show instead, and every
    /// other test in this suite opens a project — so without the argument this
    /// asserts that it ran first.
    func testLandingIntroducesTheProductAndOffersAWayIn() {
        app.launchArguments = [
            "-GopherForgeSection", Section.projects.rawValue,
            "-GopherForgeEmptyLibrary",
        ]
        app.launch()

        XCTAssertTrue(
            app.otherElements[AccessibilityIdentifier.welcomeCard].waitForExistence(timeout: 10)
                || app.staticTexts["Forge real Go, anywhere."].exists,
            "the landing screen should introduce the product"
        )
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.newProject].waitForExistence(timeout: 5),
            "the landing screen should offer a way to start something"
        )
        attachScreenshot(named: "01-projects")
    }

    /// Starting a project is one decision, so the landing screen asks it once
    /// rather than listing every template inline — but every template must
    /// still be reachable behind that one row.
    func testEveryTemplateIsOfferedBehindCreateNewProject() {
        launch(section: .projects)
        openNewProject()

        for template in ["cli", "report", "worker-pool", "tested-package"] {
            XCTAssertTrue(
                app.buttons["template.\(template)"].waitForExistence(timeout: 5),
                "template \(template) should be offered"
            )
        }
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.githubImportEntry].exists,
            "importing from GitHub should be offered alongside the templates"
        )
        attachScreenshot(named: "01b-new-project")
    }

    /// The defect that made this suite worth writing: opening a project used to
    /// change state the user could not see.
    func testOpeningATemplateLandsInTheEditor() {
        launch(section: .projects)

        openNewProject()

        let template = app.buttons["template.worker-pool"]
        XCTAssertTrue(template.waitForExistence(timeout: 10))
        template.tap()

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "opening a template should show the editor")
        XCTAssertTrue(editor.value as? String ?? "" != "", "the editor should hold the template's source")
        attachScreenshot(named: "02-editor")
    }

    func testTypingReachesTheBuffer() {
        launch(section: .build)

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        let before = editor.value as? String ?? ""

        editor.tap()
        editor.typeText("\n// forged by a UI test\n")

        let after = editor.value as? String ?? ""
        XCTAssertNotEqual(after, before, "typing should change the buffer")
        XCTAssertTrue(after.contains("forged by a UI test"))
        attachScreenshot(named: "03-typed")
    }

    /// Reported from a real phone: without this the keyboard covers half the
    /// file and nothing on screen puts it away.
    func testKeyboardCanBeDismissedFromItsOwnRow() {
        launch(section: .build)

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()

        let hide = app.buttons[AccessibilityIdentifier.hideKeyboard]
        XCTAssertTrue(hide.waitForExistence(timeout: 5), "the accessory row should offer a way out")

        hide.tap()
        // The row belongs to the keyboard, so its disappearance is the signal
        // that works whether or not a hardware keyboard is attached.
        XCTAssertTrue(
            hide.waitForNonExistence(timeout: 5),
            "tapping hide should put the keyboard away"
        )
        attachScreenshot(named: "06-keyboard-dismissed")
    }

    func testAccessoryRowOffersGoSymbols() {
        launch(section: .build)

        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()

        // The two Go needs most and iOS buries deepest.
        for symbol in [":=", "<-"] {
            XCTAssertTrue(
                app.buttons[symbol].waitForExistence(timeout: 5),
                "the accessory row should offer \(symbol)"
            )
        }

        let before = editor.value as? String ?? ""
        app.buttons[":="].tap()
        XCTAssertEqual(
            (editor.value as? String ?? "").count,
            before.count + 2,
            "tapping a symbol should insert it"
        )
    }

    func testEveryPaneCanBeSelected() {
        launch(section: .build)

        // Chips in a scrolling row, not a segmented control: six segments on a
        // phone are unreadable and the last two are unreachable.
        for pane in ["output", "tests", "idioms", "terminal", "problems"] {
            let chip = app.buttons["pane.\(pane)"]
            XCTAssertTrue(
                app.scrollHorizontally(to: chip),
                "\(pane) should be reachable, scrolling the row if it has to"
            )
            chip.tap()
            // Selection animates, so wait for it rather than asking the instant
            // after the tap — under a full suite the app is slower than it is
            // running one test alone, and that difference is not a defect.
            XCTAssertTrue(
                app.waitForSelection(of: chip),
                "\(pane) should become the selected pane"
            )
        }
        attachScreenshot(named: "04-panes")
    }

    /// The console is app-scoped: it must answer questions it can answer from
    /// the project alone, and it must never claim to have run something the
    /// toolchain cannot.
    func testTerminalAnswersFromTheProjectAndNeverInvents() {
        launch(section: .build)

        let terminal = app.buttons["pane.terminal"]
        XCTAssertTrue(app.scrollHorizontally(to: terminal))
        terminal.tap()

        let input = app.textFields["terminal.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5), "the console should offer a prompt")

        // Submitting resigns focus, so each command taps the field again
        // rather than assuming the caret stayed put.
        send("pwd", to: input)
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'playground'")).element
                .waitForExistence(timeout: 5),
            "pwd should print the module path"
        )

        // `ls` is answered from the open project, so it holds whether or not a
        // compiler is staged — which is what makes it the right thing to assert
        // in a UI test. Whether `go build` compiles or refuses is the compiler
        // gate's question, and it is asked there.
        send("ls", to: input)
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'main.go'")).element
                .waitForExistence(timeout: 5),
            "ls should list the project's own files"
        )

        send("nonsense", to: input)
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'not something this console runs'"))
                .element.waitForExistence(timeout: 5),
            "an unknown command should be refused rather than guessed at"
        )
        attachScreenshot(named: "07-terminal")
    }

    /// The invariant, not a snapshot of one configuration: an action that needs
    /// the compiler is offered exactly when the compiler is there, and never
    /// offered as a button that can only fail.
    ///
    /// This has to be written as an invariant because both states are real. A
    /// checkout with `scripts/build_toolchain.sh` run has a compiler; a CI
    /// machine with no Go does not, and the app must be honest in both.
    func testBuildActionsAreOfferedExactlyWhenTheToolchainIsThere() {
        launch(section: .build)

        let build = app.buttons["phase.build"]
        XCTAssertTrue(build.waitForExistence(timeout: 10), "the build action should always be present")
        let isMissing = app.staticTexts["Toolchain missing"].exists

        for phase in ["build", "test", "run"] {
            let button = app.buttons["phase.\(phase)"]
            XCTAssertTrue(button.exists, "the \(phase) button should be present either way")
            XCTAssertEqual(
                button.isEnabled, !isMissing,
                "the \(phase) button should be enabled exactly when a toolchain is staged"
            )
        }

        // A working compiler is not news, and a phone has no line to spare for
        // it: the strip above the editor exists only when something is wrong or
        // something is happening.
        XCTAssertEqual(
            app.element(withIdentifier: AccessibilityIdentifier.toolchainBanner).exists,
            isMissing,
            "the status strip should appear only when there is something to say"
        )
    }

    /// Reachable on both layouts. iPad shows the tree beside the editor; iPhone
    /// has no room for it and puts it behind the Files control, so the test
    /// opens it the way a person on that device would rather than assuming the
    /// wide layout.
    // MARK: - Helpers

    private enum Section: String {
        case projects
        case build
        case learn
        case settings
    }

    /// Pushes the screen where a project actually begins.
    private func openNewProject() {
        let entry = app.buttons[AccessibilityIdentifier.newProject]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "the way in should be on the landing screen")
        entry.tap()
    }

    private func launch(section: Section) {
        app.launchArguments = ["-GopherForgeSection", section.rawValue]
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
        // The drawer slides in; the tree is not there until it has.
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

    private func send(_ command: String, to field: XCUIElement) {
        field.tap()
        field.typeText(command + "\n")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Mirrors the app's identifiers. UI tests cannot import the app target, so the
/// strings are duplicated here deliberately and kept in one place so a rename
/// breaks compilation in exactly one file.
enum AccessibilityIdentifier {
    static let welcomeCard = "projects.welcome"
    static let newProject = "projects.new"
    static let githubImportEntry = "projects.github"
    static let editor = "workspace.editor"
    static let dockPicker = "workspace.dockPicker"
    static let toolchainBanner = "workspace.toolchainBanner"
    static let labScenarioPicker = "lab.scenarioPicker"
    static let labRun = "lab.run"
    static let labPrediction = "lab.prediction"
    static let reviewEntry = "learn.review"
    static let labEntry = "learn.lab"
    static let settingsToolchainStatus = "settings.toolchainStatus"
    static let hideKeyboard = "editor.hideKeyboard"
    static let settingsAppearance = "settings.appearance"
    static let fileSearch = "files.search"
    static let filesToggle = "workspace.filesToggle"
    static let drillBoard = "drill.board"
    static let exampleOpen = "example.open"
    static let quizEntry = "unit.quiz"
    static let quizContinue = "quiz.continue"
    static let quizSummary = "quiz.summary"
    static let quizRestart = "quiz.restart"
    static let lessonCheck = "lesson.check"
    static let lessonComplete = "lesson.complete"
    static let lessonCompleted = "lesson.completed"
    static let lessonUncomplete = "lesson.uncomplete"
    static let lessonVerified = "lesson.verified"
}
