import XCTest
import UIKit

/// Captures the App Store screenshots by driving the real app.
///
/// Not a test of behaviour — every assertion here exists so the run fails
/// loudly rather than quietly attaching a picture of the wrong screen. Store
/// listings are the one place where a stale or empty screenshot is invisible
/// until a reviewer sees it.
///
/// The order is the argument. The editor opens the listing with real Go code,
/// followed by real build and test output from the bundled toolchain.
/// Shots 07 to 09 — a drawn picture, a served site and the library they come
/// from — close the listing; 10 and 11 are for the README only.
///
/// Run it with `scripts/app_store_screenshots.sh`, which drives the device
/// sizes Apple asks for and collects the attachments.
/// Main-actor isolated because every XCUIElement query is: in Swift 6 a helper
/// that reaches one from a nonisolated method is a concurrency error, reported
/// as a compiler failure with no readable diagnostic behind it.
@MainActor
final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    /// A real Go build under the interpreter, on a cold cache, on whatever
    /// machine this runs on. Generous on purpose: the alternative to waiting is
    /// a screenshot of a spinner.
    private let buildTimeout: TimeInterval = 600

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testEditorEndSpaceAndTransparentLowerEdge() {
        launch(section: "projects")
        openTemplate("worker-pool")
        expectSource()
        resetOpeningDock()
        let editor = app.textViews[AccessibilityIdentifier.editor]
        let original = editor.value as? String
        editor.swipeUp()
        editor.swipeUp()
        XCTAssertEqual(editor.value as? String, original, "End space must not change source")
        captureNativeDisplayFrame("38-editor-end-space")
        app.buttons["pane.terminal"].tap()
        let command = app.textFields["terminal.input"]
        XCTAssertTrue(command.waitForExistence(timeout: 10))
        command.tap()
        app.buttons["pane.code"].tap()
        editor.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 90, dy: 120)).tap()
        let hide = app.buttons[AccessibilityIdentifier.hideKeyboard]
        XCTAssertTrue(hide.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(hide.frame.minY - editor.frame.maxY, 12)
        captureNativeDisplayFrame("38-editor-keyboard")
        hide.tap()
        XCTAssertTrue(hide.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 10))
    }

    func testCaptureInterviewReleaseScreenshots() {
        launch(section: "learn")
        let area = app.segmentedControls["learn.area"]
        XCTAssertTrue(area.waitForExistence(timeout: 10))
        area.buttons["Course"].tap()
        XCTAssertTrue(app.buttons["learn.continue"].waitForExistence(timeout: 10))
        captureNativeDisplayFrame("03-course-build41")
        area.buttons["Interview"].tap()
        XCTAssertTrue(app.buttons["interview.algorithms"].waitForExistence(timeout: 10))
        captureNativeDisplayFrame("08-interview-build41")
    }

    func testCaptureDataStoreReleaseScreenshots() {
        launch(section: "projects")
        openTemplate("worker-pool")
        expectSource()
        resetOpeningDock()
        captureNativeDisplayFrame("00-code-build38")
        launch(section: "learn")
        XCTAssertTrue(app.waitForElement(app.buttons["unit.core"]))
        captureNativeDisplayFrame("03-course-build38")
        let concurrency = app.buttons["unit.concurrency"]
        XCTAssertTrue(app.waitForElement(concurrency, scrollingUpTo: 24))
        concurrency.tap()
        let close = app.buttons["lesson.concurrency.channel-close"]
        XCTAssertTrue(app.waitForElement(close, scrollingUpTo: 16))
        close.tap()
        XCTAssertTrue(app.buttons[AccessibilityIdentifier.lessonCheck].waitForExistence(timeout: 10))
        captureNativeDisplayFrame("04-lesson-build38")
        launch(section: "learn")
        let databases = app.buttons["unit.datastores"]
        XCTAssertTrue(app.waitForElement(databases, scrollingUpTo: 30))
        databases.tap()
        let lesson = app.buttons["lesson.datastores.mongo-client"]
        XCTAssertTrue(app.waitForElement(lesson, scrollingUpTo: 8))
        lesson.tap()
        XCTAssertTrue(app.waitForElement(app.buttons["Open code in full screen"].firstMatch, scrollingUpTo: 16))
        captureNativeDisplayFrame("09-around-go-build38")
    }

    func testCaptureExpandedCourseScreenshot() {
        XCUIDevice.shared.orientation = .portrait
        launch(section: "learn")
        XCTAssertTrue(app.waitForElement(app.buttons["unit.core"]))
        captureNativeDisplayFrame("03-course-build36")
        app.terminate()
        app.launchArguments = ["-GopherForgeSection", "learn", "-GopherForgeLesson", "operations.kubernetes-inspect", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.element(withIdentifier: "lesson.reading").firstMatch.waitForExistence(timeout: 15))
        let expand = app.buttons["Open code in full screen"].firstMatch
        XCTAssertTrue(app.waitForElement(expand, scrollingUpTo: 10))
        app.swipeUp()
        captureNativeDisplayFrame("09-around-go-build36")
    }

    func testCaptureUpdatedEditorScreenshot() {
        XCUIDevice.shared.orientation = .portrait
        launch(section: "projects")
        openTemplate("worker-pool")
        expectSource()
        let hide = app.buttons[AccessibilityIdentifier.hideKeyboard]
        if hide.exists { hide.tap() }
        XCTAssertTrue(app.textViews[AccessibilityIdentifier.editor].isHittable)
        captureNativeDisplayFrame("00-code-build31")
    }

    /// One ordered walk rather than a test per screen: the shots build on each
    /// other — the library needs projects in it, the second build reuses the
    /// first one's cache — and re-launching between them would throw that away.
    func testCaptureTheListingScreenshots() {
        // The worker pool rather than the smallest template that would run.
        // The opening picture is the one that has to carry the claim, and a
        // seven-line file leaves most of a 13" editor empty — this one fills
        // it with goroutines, a channel and a WaitGroup, which is also what
        // the README says is in it.
        launch(section: "projects")
        openTemplate("worker-pool")
        expectSource()
        resetOpeningDock()
        capture("00-code")

        // Go, compiled and run here.
        runPhase("run")
        capture("01-compiler")

        // The one that shows it was not a trick: a real test run, reported per
        // case. It needs the template that ships tests.
        launch(section: "projects")
        openTemplate("tested-package")
        expectSource()

        runPhase("test")
        capture("02-tests")

        captureProblems()

        launch(section: "learn")
        XCTAssertTrue(app.waitForElement(app.buttons["unit.core"]), "the course should be on screen")
        capture("03-course")

        XCTAssertTrue(app.waitForElement(app.buttons["unit.concurrency"]))
        app.buttons["unit.concurrency"].tap()
        let lesson = app.buttons["lesson.concurrency.channel-close"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 30), "the unit should list its lessons")
        capture("10-unit")

        lesson.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.lessonCheck].waitForExistence(timeout: 30),
            "a compile lesson should offer Check"
        )
        capture("04-lesson")

        launch(section: "learn", screen: "lab")
        XCTAssertTrue(
            app.buttons[AccessibilityIdentifier.labScenario("unbuffered-rendezvous")]
                .waitForExistence(timeout: 30),
            "the lab should offer its scenarios"
        )
        capture("05-lab")

        launch(section: "projects")
        let library = app.buttons["projects.library"]
        XCTAssertTrue(app.waitForElement(library), "the dashboard should reach the library")
        library.tap()
        XCTAssertTrue(
            app.staticTexts["Unfiled"].waitForExistence(timeout: 30),
            "the library should list the projects that were opened"
        )
        capture("06-projects")

        // What the six above never showed: programs that draw, and sites
        // served from the device. Both come from the example library, which is
        // where a newcomer finds them, so the library is photographed on the
        // way in. They run after the library shot so it keeps showing the
        // projects a person made rather than examples opened for the camera.
        openExamples()
        captureExampleScreenshots()
    }

    /// Re-captures the three example screens without rebuilding the preceding
    /// templates. The normal capture above still verifies Projects navigation.
    func testCaptureExampleScreenshots() {
        launch(section: "learn", screen: "examples")
        XCTAssertTrue(app.navigationBars["Examples"].waitForExistence(timeout: 30))
        captureExampleScreenshots(relaunchExamples: true)
    }

    func testCaptureSiteScreenshot() {
        launch(section: "learn", screen: "examples")
        XCTAssertTrue(app.navigationBars["Examples"].waitForExistence(timeout: 30))
        captureSiteScreenshot()
    }

    /// The device must already have a real horizontal Duo division region.
    /// Uses the existing example project so the photos show useful Go source.
    func testCaptureNativeLaptopScreenshots() {
        launch(section: "learn", screen: "examples")
        XCTAssertTrue(app.navigationBars["Examples"].waitForExistence(timeout: 30))
        openExample("site.notes")
        XCTAssertTrue(app.selectWorkspacePane("code"))
        XCTAssertTrue(app.buttons[AccessibilityIdentifier.laptopProjectsBack].waitForExistence(timeout: 30),
                      "native Duo laptop posture must be active")
        expectSource()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 30))
        XCTAssertTrue(keyboard.isHittable)
        XCTAssertGreaterThan(keyboard.frame.height, 150, "capture must include software keys")
        XCTAssertTrue(app.buttons[AccessibilityIdentifier.laptopProjectsBack].exists)
        captureNativeDisplayFrame("duo-laptop-code")

        XCTAssertTrue(app.selectWorkspacePane("terminal"))
        XCTAssertTrue(app.textFields["terminal.input"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["terminal.quick.help"].waitForExistence(timeout: 30))
        XCTAssertTrue(keyboard.isHittable)
        XCTAssertGreaterThan(keyboard.frame.height, 150, "capture must include software keys")
        captureNativeDisplayFrame("duo-laptop-terminal")

        XCTAssertTrue(app.selectWorkspacePane("code"))
        XCTAssertTrue(app.selectWorkspacePane("idioms"))
        XCTAssertTrue(app.buttons[AccessibilityIdentifier.hideKeyboard].waitForNonExistence(timeout: 30))
        XCTAssertTrue(app.textViews[AccessibilityIdentifier.editor].exists)
        captureNativeDisplayFrame("duo-laptop-idioms")
    }

    func testCapturePhoneLandscapeScreenshots() {
        launch(section: "projects")
        openTemplate("cli")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let files = app.buttons[AccessibilityIdentifier.filesToggle]
        let search = app.textFields[AccessibilityIdentifier.fileSearch]
        XCTAssertTrue(files.waitForExistence(timeout: 10))
        if !search.waitForExistence(timeout: 2) { files.tap() }
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        captureNativeDisplayFrame("iphone-landscape-files")
        files.tap()
        XCTAssertTrue(search.waitForNonExistence(timeout: 10))
        captureNativeDisplayFrame("iphone-landscape-code")
        app.textViews[AccessibilityIdentifier.editor].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.isHittable)
        captureNativeDisplayFrame("iphone-landscape-keyboard")
    }

    func testCaptureNativeExpandedDuoScreenshots() throws {
        // Rotate the real simulator display; retain Device Hub's actual fold.
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        launch(section: "learn", screen: "examples")
        XCTAssertTrue(app.buttons["example.site.notes"].waitForExistence(timeout: 30))
        openExample("site.notes")
        guard app.windows.firstMatch.frame.width >= 600,
              !app.buttons[AccessibilityIdentifier.laptopProjectsBack].exists else {
            throw XCTSkip("Select the native Open or Book Duo posture before capture")
        }
        let files = app.buttons[AccessibilityIdentifier.filesToggle]
        let search = app.textFields[AccessibilityIdentifier.fileSearch]
        XCTAssertTrue(files.waitForExistence(timeout: 10))
        if search.exists { files.tap() }
        XCTAssertTrue(search.waitForNonExistence(timeout: 10))
        captureNativeDisplayFrame("duo-expanded-code")
        files.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        captureNativeDisplayFrame("duo-expanded-files")
        files.tap()
        let editor = app.textViews[AccessibilityIdentifier.editor]
        editor.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.isHittable)
        captureNativeDisplayFrame("duo-expanded-keyboard")
    }

    private func captureExampleScreenshots(relaunchExamples: Bool = false) {
        capture("09-examples")

        openExample("graphics.mandelbrot")
        runPhase("run")
        showOutput()
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "output.image.mandelbrot.png")
                .firstMatch
                .waitForExistence(timeout: 120),
            "the Mandelbrot example should show the picture it drew"
        )
        capture("07-graphics")

        if relaunchExamples {
            launch(section: "learn", screen: "examples")
            XCTAssertTrue(app.navigationBars["Examples"].waitForExistence(timeout: 30))
        } else {
            openExamples()
        }
        captureSiteScreenshot()
    }

    private func captureSiteScreenshot() {
        openExample("site.notes")
        runPhase("run")
        showOutput()
        XCTAssertTrue(
            app.staticTexts[AccessibilityIdentifier.outputSite].waitForExistence(timeout: 120),
            "a site example should publish its localhost URL in Output"
        )
        // The address appears before the page does: the preview is a web view
        // loading from the app's own loopback server, and a shot taken on the
        // address alone is a shot of an empty grey box.
        XCTAssertTrue(
            app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sticky notes'"))
                .firstMatch
                .waitForExistence(timeout: 120),
            "the preview should show the page the project serves"
        )
        XCTAssertTrue(waitForSitePaint(), "the site's pixels should be painted before photographing it")
        capture("08-site")
    }

    /// WebKit can publish its accessibility tree before its compositor paints
    /// the page on an overloaded simulator. Sample the interior of the real
    /// preview so a uniform placeholder cannot pass as a finished screenshot.
    private func waitForSitePaint() -> Bool {
        let webView = app.webViews.firstMatch
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if let image = webView.screenshot().image.cgImage {
                let side = 24
                var pixels = [UInt8](repeating: 0, count: side * side * 4)
                let painted = pixels.withUnsafeMutableBytes { bytes -> Bool in
                    guard let context = CGContext(
                        data: bytes.baseAddress, width: side, height: side,
                        bitsPerComponent: 8, bytesPerRow: side * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    ) else { return false }
                    context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
                    let samples = bytes.bindMemory(to: UInt8.self)
                    var colors = Set<Int>()
                    for y in 4..<20 {
                        for x in 4..<20 {
                            let i = (y * side + x) * 4
                            colors.insert(Int(samples[i] / 16) << 8
                                | Int(samples[i + 1] / 16) << 4
                                | Int(samples[i + 2] / 16))
                        }
                    }
                    return colors.count >= 6
                }
                if painted { return true }
            }
            Thread.sleep(forTimeInterval: 2)
        }
        return false
    }

    /// Breaks the open project on purpose, builds it, and photographs what the
    /// compiler said.
    ///
    /// An empty Problems pane is not a picture of anything, so the diagnostic
    /// has to be real — and it is produced by breaking the file and building
    /// rather than by staging a message, so the shot cannot outlive the parser
    /// that produced it. `declared and not used` is the one Go is best known
    /// for, and the one a newcomer meets first.
    ///
    /// This runs after the two build shots and before the course, so the
    /// screenshots that claim a working compiler are taken while the project
    /// still compiles.
    private func captureProblems() {
        let editor = app.textViews[AccessibilityIdentifier.editor]

        // iPhone shows the panes as full-height tabs, so the test run that was
        // just photographed is still covering the editor and there is nothing
        // to type into. iPad keeps the editor beside the dock, so this asks
        // rather than assumes.
        if !editor.waitForExistence(timeout: 5) {
            revealPhoneEditor()
        }

        XCTAssertTrue(editor.waitForExistence(timeout: 30), "the workspace should still hold the file")

        // Below the last line of a seven-line file, which is where a text view
        // puts the caret when you tap past the end of its text.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        editor.typeText("\n\nfunc unusedExample() {\n    unusedTotal := 0\n}\n")

        // The keyboard covers the pane this is a screenshot of.
        let hide = app.buttons[AccessibilityIdentifier.hideKeyboard]
        if hide.waitForExistence(timeout: 5) { hide.tap() }

        runPhase("build")

        let problems = app.buttons["pane.problems"]
        XCTAssertTrue(app.tapReachable(problems), "the Problems pane should be reachable")
        XCTAssertTrue(app.waitForSelection(of: problems), "Problems should become the selected pane")
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'unusedTotal'"))
                .element.waitForExistence(timeout: 60),
            "a build that cannot succeed should be reported in Problems"
        )
        capture("11-problems")
    }

    // MARK: - Helpers

    private func launch(section: String, screen: String? = nil) {
        // No terminate first: `launch()` already relaunches, and terminating an
        // app that has not started yet fails the run before it reaches a screen.
        var arguments = ["-GopherForgeSection", section,
                         "-editorFontSize", "14",
                         "-appearanceMode", "light"]
        if let screen { arguments += ["-GopherForgeScreen", screen] }
        app.launchArguments = arguments
        app.launch()
    }

    /// Presses a build action and waits for it to finish.
    ///
    /// Finished means the progress strip has gone, not that the button was
    /// tapped — a screenshot taken a second after the tap is a screenshot of a
    /// spinner, and it would go into the listing looking deliberate.
    private func runPhase(_ phase: String) {
        var action = app.buttons["phase.\(phase)"]
        if !action.waitForExistence(timeout: 3) {
            let menu = app.buttons[AccessibilityIdentifier.projectMenu]
            XCTAssertTrue(menu.waitForExistence(timeout: 10), "compile-check lives in the project menu")
            menu.tap()
            action = app.buttons["phase.\(phase)"]
        }
        XCTAssertTrue(action.waitForExistence(timeout: 30), "the workspace should offer \(phase)")
        XCTAssertTrue(
            action.isEnabled,
            "\(phase) is disabled, which means no toolchain is staged — "
                + "run scripts/build_toolchain.sh before capturing the listing"
        )
        action.tap()

        // Compile-check lives in the project menu. Tapping it dismisses the
        // menu, so the button this bound is gone and `isEnabled` throws.
        // Run stays on the bar and is disabled for every phase.
        let bar = app.buttons["phase.run"]
        let warming = Date().addingTimeInterval(3)
        while Date() < warming {
            if bar.exists && !bar.isEnabled { break }
            _ = bar.waitForExistence(timeout: 0.2)
        }
        let deadline = Date().addingTimeInterval(buildTimeout)
        var finished = false
        while Date() < deadline {
            if bar.exists && bar.isEnabled {
                finished = true
                break
            }
            _ = bar.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(finished, "\(phase) did not finish within \(Int(buildTimeout))s")
    }

    /// Returns to the editor after the test output has covered it on iPhone.
    private func revealPhoneEditor() {
        let code = app.buttons["pane.code"]
        XCTAssertTrue(app.tapReachable(code), "the Code pane should be reachable")
        XCTAssertTrue(app.waitForSelection(of: code), "Code should become the selected pane")
    }

    /// Asserts the editor arrived and has the template's source in it.
    private func expectSource(timeout: TimeInterval = 30) {
        let editor = app.textViews[AccessibilityIdentifier.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: timeout), "opening a template should land in the editor")
        XCTAssertFalse(
            (editor.value as? String ?? "").isEmpty,
            "the editor should hold the template's source"
        )
    }

    private func openTemplate(_ id: String) {
        let create = app.buttons[AccessibilityIdentifier.newProject]
        XCTAssertTrue(app.waitForElement(create), "the dashboard should offer a way to start")
        create.tap()

        // Generous, because a capture on a busy Mac is slow rather than wrong:
        // a 6.5-inch run once waited more than thirty seconds for this sheet.
        let template = app.buttons["template.\(id)"]
        XCTAssertTrue(template.waitForExistence(timeout: 120), "template \(id) should be offered")
        template.tap()

        let confirm = app.buttons[AccessibilityIdentifier.newProjectCreate]
        XCTAssertTrue(confirm.waitForExistence(timeout: 60), "the name screen should offer Create")
        confirm.tap()
    }

    /// The example library, reached the way a person reaches it: from the
    /// Projects dashboard rather than a launch argument.
    private func openExamples() {
        launch(section: "projects")
        let examples = app.buttons[AccessibilityIdentifier.projectsExamples]
        XCTAssertTrue(app.waitForElement(examples), "the dashboard should offer the example library")
        examples.tap()
        XCTAssertTrue(
            app.navigationBars["Examples"].waitForExistence(timeout: 10),
            "Examples should open the library"
        )
    }

    /// Opens one example into the workspace, where it is an ordinary project.
    private func openExample(_ id: String) {
        let example = app.buttons["example.\(id)"]
        XCTAssertTrue(app.waitForElement(example), "example \(id) should be in the library")
        example.tap()

        let open = app.buttons[AccessibilityIdentifier.exampleOpen]
        XCTAssertTrue(open.waitForExistence(timeout: 30), "an example should offer Open in workspace")
        if id == "site.notes" { capture("example-site-source-preview") }
        open.tap()
        // A site example opens with its web files and vendored Gin, which is a
        // much bigger project than a template; on a busy Mac the iPad took
        // longer than thirty seconds to show its editor.
        expectSource(timeout: 180)
    }

    /// Brings Output forward and, on iPad, gives it the room a picture needs.
    ///
    /// The dock opens at 280 points: enough for lines of text, and half of a
    /// drawn image or a site preview. The height is remembered, so raising it
    /// once serves both shots that need it; the app clamps it at 640.
    private func showOutput() {
        let output = app.buttons["pane.output"]
        XCTAssertTrue(app.tapReachable(output), "the Output pane should be reachable")
        XCTAssertTrue(app.waitForSelection(of: output), "Output should become the selected pane")

        // The phone stacks its panes full height and has no seam to drag.
        let handle = app.otherElements[AccessibilityIdentifier.dockResizeHandle]
        guard handle.waitForExistence(timeout: 2) else { return }

        // Slowly, with a hold at each end, for the reason the dock test gives:
        // a jump with no events between is a drag the gesture never sees.
        let seat = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        seat.press(
            forDuration: 0.3,
            thenDragTo: seat.withOffset(CGVector(dx: 0, dy: -400)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )
    }

    private func resetOpeningDock() {
        let handle = app.otherElements[AccessibilityIdentifier.dockResizeHandle]
        guard handle.waitForExistence(timeout: 2),
              let value = handle.value as? String,
              let height = Double(value.split(separator: " ").first ?? "") else { return }
        guard abs(height - 280) > 10 else { return }
        let seat = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        seat.press(forDuration: 0.3,
                   thenDragTo: seat.withOffset(CGVector(dx: 0, dy: height - 280)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// XCTest currently captures the inactive outer display on Duo. The host
    /// screenshot driver uses this marker to capture the enumerated inner
    /// display with public simctl while the verified UI remains unchanged.
    private func captureNativeDisplayFrame(_ name: String) {
        // A view can exist while its navigation/rotation animation is still
        // committing to the native framebuffer.
        Thread.sleep(forTimeInterval: 2)
        // XCTest may launch an isolated copy while simctl still sees the
        // ordinary installation. Keep the tested UI as evidence too; a host
        // framebuffer capture must verify the installed build and active area.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("GF_NATIVE_FRAME_READY: \(name)")
        fflush(stdout)
        let requested = ProcessInfo.processInfo.environment["GF_CAPTURE_HOLD_SECONDS"].flatMap(Double.init) ?? 30
        Thread.sleep(forTimeInterval: min(30, max(8, requested)))
    }

    /// Named with a leading number so the files sort into listing order once
    /// they are exported.
    ///
    /// Waits before shooting. Existing is not the same as settled: every one of
    /// these screens animates something into place — a pane crossfading its
    /// empty state out, a chip's selection easing in — and `runPhase` returning
    /// means the work finished, not that the screen has caught up. One capture
    /// came back with the Output pane's "No problems" placeholder and its real
    /// result both half transparent, drawn on top of each other.
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1.5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
