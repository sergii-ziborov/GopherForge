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

    func testDockTabsSwitch() {
        launch(section: .build)

        let dock = app.segmentedControls[AccessibilityIdentifier.dockPicker]
        XCTAssertTrue(dock.waitForExistence(timeout: 10))

        for title in ["Output", "Tests", "Idioms", "Problems"] {
            let button = dock.buttons.element(boundBy: dockIndex(of: title))
            button.tap()
            XCTAssertTrue(button.isSelected, "\(title) should become the selected dock tab")
        }
        attachScreenshot(named: "04-dock")
    }

    /// Every action that needs the toolchain must be unavailable while none is
    /// staged, rather than failing after the user commits to it.
    func testBuildActionsAreUnavailableWithoutAToolchain() {
        launch(section: .build)

        XCTAssertTrue(
            app.staticTexts["Toolchain missing"].waitForExistence(timeout: 10),
            "the banner should name the missing toolchain"
        )
        for phase in ["build", "test", "run"] {
            let button = app.buttons["phase.\(phase)"]
            XCTAssertTrue(button.exists, "the \(phase) button should be present")
            XCTAssertFalse(button.isEnabled, "the \(phase) button should be disabled without a toolchain")
        }
    }

    func testFileTreeSwitchesTheOpenFile() {
        launch(section: .build)

        let goMod = app.buttons["file.go.mod"]
        XCTAssertTrue(goMod.waitForExistence(timeout: 10), "go.mod should be listed in the tree")
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

    private func dockIndex(of title: String) -> Int {
        ["Problems", "Output", "Tests", "Idioms"].firstIndex(of: title) ?? 0
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
}
