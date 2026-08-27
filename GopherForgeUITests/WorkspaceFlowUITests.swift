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

    func testLandingOffersTemplatesOnAFirstRun() {
        launch(section: .projects)

        XCTAssertTrue(
            app.otherElements[AccessibilityIdentifier.welcomeCard].waitForExistence(timeout: 10)
                || app.staticTexts["Forge real Go, anywhere."].exists,
            "the landing screen should introduce the product"
        )
        for template in ["cli", "report", "worker-pool", "tested-package"] {
            XCTAssertTrue(
                app.buttons["template.\(template)"].exists,
                "template \(template) should be offered"
            )
        }
        attachScreenshot(named: "01-projects")
    }

    /// The defect that made this suite worth writing: opening a project used to
    /// change state the user could not see.
    func testOpeningATemplateLandsInTheEditor() {
        launch(section: .projects)

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

        let picker = app.segmentedControls[AccessibilityIdentifier.dockPicker]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))

        for title in ["Output", "Tests", "Idioms", "Terminal", "Problems"] {
            let button = picker.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", title)
            ).firstMatch
            XCTAssertTrue(button.exists, "\(title) should be offered")
            button.tap()
            XCTAssertTrue(button.isSelected, "\(title) should become the selected pane")
        }
        attachScreenshot(named: "04-panes")
    }

    /// The console is app-scoped: it must answer questions it can answer from
    /// the project alone, and it must never claim to have run something the
    /// toolchain cannot.
    func testTerminalAnswersFromTheProjectAndNeverInvents() {
        launch(section: .build)

        let picker = app.segmentedControls[AccessibilityIdentifier.dockPicker]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Terminal'")).firstMatch.tap()

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
    func testFileTreeSwitchesTheOpenFile() {
        launch(section: .build)

        let goMod = app.buttons["file.go.mod"]
        if !goMod.waitForExistence(timeout: 10) {
            let files = app.buttons["Files"]
            XCTAssertTrue(
                files.waitForExistence(timeout: 5),
                "a layout with no visible tree must offer a way to open one"
            )
            files.tap()
        }
        XCTAssertTrue(goMod.waitForExistence(timeout: 5), "go.mod should be listed in the tree")
        goMod.tap()

        let editor = app.textViews[AccessibilityIdentifier.editor]
        let contents = editor.value as? String ?? ""
        XCTAssertTrue(contents.contains("module "), "selecting go.mod should show the module file")
        attachScreenshot(named: "05-gomod")
    }

    // MARK: - Helpers

    private enum Section: String {
        case projects
        case build
        case learn
        case settings
    }

    private func launch(section: Section) {
        app.launchArguments = ["-GopherForgeSection", section.rawValue]
        app.launch()
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
    static let drillBoard = "drill.board"
    static let exampleOpen = "example.open"
}
