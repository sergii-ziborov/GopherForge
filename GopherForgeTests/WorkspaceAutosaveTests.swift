import XCTest
@testable import GopherForge

/// What the editor types must survive leaving the editor.
///
/// The workspace used to fold the buffer into the project only when something
/// asked for the project — a build, or opening another file — and it never
/// wrote the project to the library except on open and after a build. So text
/// typed and not built existed in one buffer that nothing persisted: switching
/// tab and vendoring a package overwrote it from a stale project, and quitting
/// lost it. These are the paths that lost it.
@MainActor
final class WorkspaceAutosaveTests: XCTestCase {
    private var storageURL: URL!
    private var library: ProjectLibrary!

    override func setUpWithError() throws {
        storageURL = FileManager.default.temporaryDirectory
            .appending(path: "autosave-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "projects.json")
        library = ProjectLibrary(storageURL: storageURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storageURL.deletingLastPathComponent())
        library = nil
        storageURL = nil
    }

    private func openedWorkspace() async -> WorkspaceModel {
        let workspace = WorkspaceModel(library: library)
        workspace.open(
            GopherForgeProject(
                name: "Autosave",
                files: ["main.go": "package main\n\nfunc main() {}\n"],
                entryFile: "main.go",
                provenance: nil
            )
        )
        await workspace.libraryUpdated()
        return workspace
    }

    /// The in-memory half. Export, the package installer and every phase read
    /// `project`, so an edit that has not reached it is already lost to them.
    func testTypingReachesTheProjectWithoutBuilding() async {
        let workspace = await openedWorkspace()
        workspace.updateEditorText("package main\n\n// typed\nfunc main() {}\n")

        XCTAssertEqual(
            workspace.project?.files["main.go"],
            "package main\n\n// typed\nfunc main() {}\n",
            "an edit should be in the project before anything asks for it"
        )
    }

    /// The on-disk half, which is what surviving a relaunch means.
    func testTypingIsPersistedWithoutBuilding() async throws {
        let workspace = await openedWorkspace()
        workspace.updateEditorText("package main\n\n// persisted\nfunc main() {}\n")
        await workspace.flush()

        let items = try await library.items()
        XCTAssertEqual(
            items.first?.project.files["main.go"],
            "package main\n\n// persisted\nfunc main() {}\n",
            "the library should hold what was typed, with no build in between"
        )
    }

    /// The chain that overwrote source: vendoring reads the project, and the
    /// project used to be whatever it was the last time somebody built.
    func testVendoringAPackageKeepsAnUnbuiltEdit() async {
        let workspace = await openedWorkspace()
        workspace.updateEditorText("package main\n\n// mine\nfunc main() {}\n")

        // What the installer does: takes the project's files, adds to them,
        // and hands the whole set back.
        var files = workspace.project?.files ?? [:]
        files["vendor/example.com/dep/dep.go"] = "package dep\n"
        workspace.replaceFiles(with: files)

        XCTAssertEqual(
            workspace.project?.files["main.go"],
            "package main\n\n// mine\nfunc main() {}\n",
            "vendoring should not roll the open file back"
        )
        XCTAssertNotNil(
            workspace.project?.files["vendor/example.com/dep/dep.go"],
            "and it should still have added the dependency"
        )
    }

    /// Reopening is how the user finds out whether anything was kept.
    func testAnEditSurvivesReopeningTheProject() async throws {
        let workspace = await openedWorkspace()
        workspace.updateEditorText("package main\n\n// survives\nfunc main() {}\n")
        await workspace.flush()

        let reopened = WorkspaceModel(library: library)
        let stored = try await library.items().first?.project
        let project = try XCTUnwrap(stored)
        reopened.open(project)

        XCTAssertEqual(
            reopened.editorText,
            "package main\n\n// survives\nfunc main() {}\n",
            "the editor should come back holding what was left in it"
        )
    }

    /// Switching files must not lose either one.
    func testSwitchingFilesKeepsBothEdits() async {
        let workspace = await openedWorkspace()
        workspace.updateEditorText("package main\n\n// first\nfunc main() {}\n")

        var files = workspace.project?.files ?? [:]
        files["second.go"] = "package main\n"
        workspace.replaceFiles(with: files)

        workspace.select(file: "second.go")
        workspace.updateEditorText("package main\n\n// second\n")
        workspace.select(file: "main.go")

        XCTAssertEqual(workspace.project?.files["second.go"], "package main\n\n// second\n")
        XCTAssertEqual(
            workspace.project?.files["main.go"],
            "package main\n\n// first\nfunc main() {}\n"
        )
    }
}
