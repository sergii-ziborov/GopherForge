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

    func testCreatingFilesAndEmptyFoldersSurvivesSavingAndReopening() async throws {
        let workspace = await openedWorkspace()
        let folder = try workspace.createFolder(named: "handlers")
        XCTAssertEqual(folder, "handlers")
        XCTAssertEqual(workspace.project?.files["handlers/.gopherforge-folder"], "")
        let file = try workspace.createFile(named: "server.go", in: folder)
        XCTAssertEqual(file, "handlers/server.go")
        XCTAssertEqual(workspace.selectedFile, file)
        XCTAssertTrue(workspace.editorText.hasPrefix("package handlers"))
        workspace.updateEditorText("package handlers\n\nfunc Serve() {}\n")
        await workspace.flush()

        let items = try await library.items()
        let item = try XCTUnwrap(items.first)
        let reopened = WorkspaceModel(library: library)
        XCTAssertTrue(reopened.open(item))
        XCTAssertEqual(reopened.project?.files[file], "package handlers\n\nfunc Serve() {}\n")
        XCTAssertEqual(reopened.project?.files["handlers/.gopherforge-folder"], "")
    }

    func testRenameAndDeleteKeepEntryAndSelectedFileValid() async throws {
        let workspace = await openedWorkspace()
        try workspace.createFolder(named: "cmd")
        let first = try workspace.createFile(named: "tool.go", in: "cmd")
        workspace.updateEditorText("package main\nfunc main() {}\n")
        try workspace.renameFolder(at: "cmd", to: "bin")
        XCTAssertEqual(workspace.selectedFile, "bin/tool.go")
        XCTAssertEqual(workspace.project?.files["bin/tool.go"], "package main\nfunc main() {}\n")

        try workspace.renameFile(at: "main.go", to: "start.go")
        XCTAssertEqual(workspace.project?.entryFile, "start.go")
        XCTAssertThrowsError(try workspace.createFile(named: "start.go"))
        XCTAssertThrowsError(try workspace.createFile(named: "../outside.go"))

        try workspace.deleteFolder(at: "bin")
        XCTAssertEqual(workspace.selectedFile, "start.go")
        XCTAssertEqual(workspace.project?.files[first], nil)
        XCTAssertThrowsError(try workspace.deleteFile(at: "start.go"))
        await workspace.flush()
        let items = try await library.items()
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.project.entryFile, "start.go")
    }

    func testOpeningAnotherProjectOrReopeningSameOneClearsRunState() async throws {
        let workspace = await openedWorkspace()
        let items = try await library.items()
        let item = try XCTUnwrap(items.first)
        let firstGeneration = workspace.projectGeneration
        XCTAssertTrue(workspace.open(item))
        XCTAssertGreaterThan(workspace.projectGeneration, firstGeneration)
        XCTAssertEqual(workspace.selectedFile, "main.go")
        XCTAssertNil(workspace.lastResult)

        XCTAssertTrue(workspace.open(ProjectTemplate.commandLineTool.project(named: "Next")))
        XCTAssertNil(workspace.lastResult)
        XCTAssertGreaterThan(workspace.projectGeneration, firstGeneration + 1)
    }

    func testSwitchingProjectsBeforeDebounceKeepsTheFirstEdit() async throws {
        let workspace = await openedWorkspace()
        let firstID = try XCTUnwrap(workspace.projectID)
        workspace.updateEditorText("package main\n// changed before switch\n")
        workspace.open(GopherForgeProject(
            name: "Second", files: ["main.go": "package main\n"],
            entryFile: "main.go", provenance: nil
        ))
        await workspace.libraryUpdated()

        let first = try await library.project(id: firstID)
        XCTAssertEqual(first?.project.files["main.go"], "package main\n// changed before switch\n")
        let items = try await library.items()
        XCTAssertEqual(items.count, 2)
    }

    func testPrepareRestoresSavedProjectInsteadOfReplacingItWithPlayground() async throws {
        let id = UUID()
        let original = ProjectTemplate.commandLineTool.project(named: "Playground")
        var files = original.files
        files[original.entryFile] = "package main\n// kept after relaunch\nfunc main() {}\n"
        let edited = GopherForgeProject(
            name: original.name, files: files,
            entryFile: original.entryFile, provenance: original.provenance
        )
        _ = try await library.recordSource(id: id, revision: 3, project: edited)

        let reopened = WorkspaceModel(library: library)
        await reopened.prepare()
        XCTAssertEqual(reopened.projectID, id)
        XCTAssertEqual(reopened.editorText, files[original.entryFile])
        let restoredItems = try await library.items()
        XCTAssertEqual(restoredItems.count, 1)
    }

    func testSaveFailureIsVisibleAndRetryKeepsTheEdit() async throws {
        let root = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appending(path: "blocked")
        try Data("not a directory".utf8).write(to: blocker)
        let failingLibrary = ProjectLibrary(storageURL: blocker.appending(path: "projects.json"))
        let workspace = WorkspaceModel(library: failingLibrary)
        workspace.open(GopherForgeProject(
            name: "Retry", files: ["main.go": "package main\n"],
            entryFile: "main.go", provenance: nil
        ))
        await workspace.libraryUpdated()
        workspace.updateEditorText("package main\n// still here\n")
        await workspace.flush()
        XCTAssertNotNil(workspace.saveError)
        XCTAssertTrue(workspace.hasUnsavedChanges)

        try FileManager.default.removeItem(at: blocker)
        await workspace.retrySave()
        XCTAssertNil(workspace.saveError)
        XCTAssertFalse(workspace.hasUnsavedChanges)
        let stored = try await failingLibrary.items()
        XCTAssertEqual(stored.first?.project.files["main.go"], "package main\n// still here\n")
    }

    func testRenameKeepsLiveUnsavedSourceAndProjectID() async throws {
        let workspace = await openedWorkspace()
        let id = try XCTUnwrap(workspace.projectID)
        workspace.updateEditorText("package main\n// not yet saved\n")
        _ = try await library.update(id: id, name: "Renamed")
        let updatedItem = try await library.project(id: id)
        workspace.refreshMetadata(from: try XCTUnwrap(updatedItem))

        XCTAssertEqual(workspace.projectID, id)
        XCTAssertEqual(workspace.project?.name, "Renamed")
        XCTAssertEqual(workspace.editorText, "package main\n// not yet saved\n")
        await workspace.flush()
        let stored = try await library.project(id: id)
        XCTAssertEqual(stored?.project.name, "Renamed")
        XCTAssertEqual(stored?.project.files["main.go"], "package main\n// not yet saved\n")
    }

    func testSelectingAnotherMainFileChangesTheRunTarget() async {
        let workspace = await openedWorkspace()
        var files = workspace.project?.files ?? [:]
        files["cmd/other/main.go"] = "package main\nfunc main() {}\n"
        workspace.replaceFiles(with: files)
        XCTAssertEqual(workspace.selectedTargetPattern, ".")
        workspace.select(file: "cmd/other/main.go")
        XCTAssertEqual(workspace.selectedTargetPattern, "./cmd/other")
        workspace.select(file: "go.mod")
        XCTAssertEqual(workspace.selectedTargetPattern, ".")
    }

    func testRemovingAPackageDropsItsVendoredFiles() async {
        let workspace = await openedWorkspace()
        var files = workspace.project?.files ?? [:]
        files["go.mod"] = "module playground\n\ngo 1.24\n\nrequire (\n\texample.com/dep v1.0.0\n)\n"
        files["vendor/example.com/dep/dep.go"] = "package dep\n"
        files["vendor/modules.txt"] = "# example.com/dep v1.0.0\n## explicit\nexample.com/dep\n"
        workspace.replaceFiles(with: files)

        workspace.removePackage("example.com/dep")

        XCTAssertNil(workspace.project?.files["vendor/example.com/dep/dep.go"])
        XCTAssertEqual(
            GoVendorWriter.installedModules(in: workspace.project?.files ?? [:]),
            []
        )
    }

    func testOpeningADiagnosticMarksThatLineUntilItIsEdited() async {
        let workspace = await openedWorkspace()
        workspace.updateEditorText("package main\n\nfunc main() {\n\t_ = unused\n}\n")

        workspace.select(file: "main.go", revealingLine: 4)
        XCTAssertEqual(workspace.markedLines, [4])
        XCTAssertEqual(workspace.revealLine, 4)

        workspace.updateEditorText("package main\n\nfunc main() {\n\t_ = unused\n}\n")
        XCTAssertEqual(workspace.markedLines, [4], "an identical buffer is not an edit")

        workspace.updateEditorText("package main\n\nfunc main() {\n\tfmt.Println(1)\n}\n")
        XCTAssertTrue(workspace.markedLines.isEmpty, "editing the marked line should drop the highlight")
    }

    func testEditingADifferentLineKeepsTheDiagnosticMark() async {
        let workspace = await openedWorkspace()
        workspace.updateEditorText("package main\n\nfunc main() {\n\t_ = unused\n}\n")
        workspace.select(file: "main.go", revealingLine: 4)

        workspace.updateEditorText("package playground\n\nfunc main() {\n\t_ = unused\n}\n")
        XCTAssertEqual(workspace.markedLines, [4])
    }

    func testOpeningASiteExampleServesLocalhost() async throws {
        let workspace = WorkspaceModel(library: library)
        workspace.open(GoExampleProjectGinCafe.cafe.project())
        await workspace.libraryUpdated()

        let url = try XCTUnwrap(workspace.sitePreviewURL)
        XCTAssertEqual(url.host, "127.0.0.1")
        XCTAssertGreaterThan(url.port ?? 0, 0)

        let (data, response) = try await URLSession.shared.data(from: url)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("Gopher Café"))

        workspace.open(
            GopherForgeProject(
                name: "Plain",
                files: ["main.go": "package main\n"],
                entryFile: "main.go",
                provenance: nil
            )
        )
        XCTAssertNil(workspace.sitePreviewURL)
    }
}
