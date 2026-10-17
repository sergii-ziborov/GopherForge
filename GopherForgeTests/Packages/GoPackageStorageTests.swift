import XCTest
@testable import GopherForge

final class GoPackageStorageTests: XCTestCase {
    private func project(_ name: String, provenance: GopherForgeProject.Provenance? = .files()) -> GopherForgeProject {
        GopherForgeProject(name: name, files: [
            "go.mod": "module example.com/\(name)\n\ngo 1.18\n\nrequire example.com/dep v1.0.0\n",
            "go.sum": "example.com/dep v1.0.0 h1:kept=\n",
            "main.go": "package main\nimport _ \"example.com/dep\"\nfunc main() {}\n",
            "main_test.go": "package main\n// my tests\n",
            "vendor/example.com/dep/dep.go": "package dep\n",
            "vendor/modules.txt": "# example.com/dep v1.0.0\n## explicit\nexample.com/dep\n",
            "vendor/local-not-a-module/custom.go": "package custom\n",
        ], entryFile: "main.go", provenance: provenance)
    }

    func testCleanupPreservesCodeTestsRequirementsChecksumsAndUnlistedSource() {
        let original = project("mine")
        let cleaned = GoPackageStorage.clearingDownloadedPackages(from: original)
        XCTAssertEqual(cleaned.summary.projectCount, 1)
        XCTAssertEqual(cleaned.summary.fileCount, 1)
        XCTAssertNil(cleaned.project.files["vendor/example.com/dep/dep.go"])
        XCTAssertNil(cleaned.project.files["vendor/modules.txt"])
        for name in ["main.go", "main_test.go", "go.mod", "go.sum", "vendor/local-not-a-module/custom.go"] {
            XCTAssertEqual(cleaned.project.files[name], original.files[name], name)
        }
        XCTAssertEqual(GoPackageStorage.summary(in: cleaned.project).fileCount, 0)
    }

    func testExamplesIncludingLegacyCopiesAndLessonWorkspacesAreExcluded() {
        let example = GoExampleLibrary.all[0].project()
        let legacy = GopherForgeProject(name: "Renamed old example", files: example.files,
            entryFile: example.entryFile, provenance: .template())
        let lesson = project("lesson").replacingFiles([
            "go.mod": "module lesson\nrequire example.com/dep v1.0.0\n",
            "lesson_test.go": "package main\n",
            "vendor/example.com/dep/dep.go": "package dep\n",
        ])
        for protected in [example, legacy, lesson] {
            XCTAssertEqual(GoPackageStorage.clearingDownloadedPackages(from: protected).project, protected)
            XCTAssertEqual(GoPackageStorage.summary(in: protected).fileCount, 0)
        }
    }

    func testVendorOnlyDependencyIsPinnedWithoutChangingReplaceBlocks() {
        let originalMod = """
        module example.com/mine
        go 1.18
        replace (
            example.com/old => example.com/new v1.0.0
        )
        """
        let original = project("mine").replacingFiles([
            "go.mod": originalMod,
            "main.go": "package main\n",
            "vendor/modules.txt": "# example.com/dep v1.2.3\n## explicit\nexample.com/dep\n",
            "vendor/example.com/dep/dep.go": "package dep\n",
        ])
        let cleaned = GoPackageStorage.clearingDownloadedPackages(from: original)
        let goMod = cleaned.project.files["go.mod"] ?? ""
        XCTAssertTrue(goMod.hasPrefix(originalMod))
        XCTAssertTrue(goMod.contains(")\n\nrequire example.com/dep v1.2.3\n"))
        XCTAssertEqual(cleaned.project.module?.requirements.first?.version, "v1.2.3")
        XCTAssertEqual(cleaned.project.module?.replacements.first?.path, "example.com/old")
        XCTAssertNil(cleaned.project.files["vendor/example.com/dep/dep.go"])
    }

    func testCleanupPersistsForEveryUserProjectAndRejectsAStaleSave() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            .appending(path: "projects.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let library = ProjectLibrary(storageURL: url)
        let first = UUID(), second = UUID(), exampleID = UUID()
        let a = project("first"), b = project("second")
        let example = GoExampleLibrary.all[0].project()
        _ = try await library.recordSource(id: first, revision: 7, project: a)
        _ = try await library.recordSource(id: second, revision: 3, project: b)
        _ = try await library.recordSource(id: exampleID, revision: 0, project: example)
        let result = try await library.clearDownloadedPackages()
        XCTAssertEqual(result.summary.projectCount, 2)
        _ = try await library.recordSource(id: first, revision: 7, project: a)
        let reopened = ProjectLibrary(storageURL: url)
        let items = try await reopened.items()
        for id in [first, second] {
            let stored = try XCTUnwrap(items.first { $0.id == id })
            XCTAssertNil(stored.project.files["vendor/example.com/dep/dep.go"])
            XCTAssertNotNil(stored.project.files["main_test.go"])
        }
        let preserved = items.first { $0.id == exampleID }?.project
        XCTAssertEqual(preserved?.files, example.files)
        XCTAssertEqual(preserved?.provenance?.reference, example.provenance?.reference)
    }

    @MainActor
    func testStorageSummaryIncludesPackagesBeforeAutosaveFires() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            .appending(path: "projects.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: url))
        let downloaded = project("current")
        workspace.open(downloaded.replacingFiles(downloaded.files.filter { !$0.key.hasPrefix("vendor/") }))
        await workspace.libraryUpdated()
        workspace.replaceFiles(with: downloaded.files)
        let summary = try await workspace.downloadedPackageStorage()
        XCTAssertEqual(summary.projectCount, 1)
        XCTAssertEqual(summary.fileCount, 1)
    }

    @MainActor
    func testWorkspaceCleanupKeepsUnsavedEditsAndCannotRestoreOldPackagesOnFlush() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            .appending(path: "projects.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let library = ProjectLibrary(storageURL: url)
        let workspace = WorkspaceModel(library: library)
        workspace.open(project("current"))
        await workspace.libraryUpdated()
        workspace.updateEditorText("package main\n// my latest edit\nfunc main() {}\n")
        let removed = try await workspace.clearDownloadedPackages()
        XCTAssertEqual(removed.projectCount, 1)
        XCTAssertTrue(workspace.editorText.contains("my latest edit"))
        XCTAssertNil(workspace.project?.files["vendor/example.com/dep/dep.go"])
        await workspace.flush()
        let stored = try await library.items()
        XCTAssertNil(stored.first?.project.files["vendor/example.com/dep/dep.go"])
        XCTAssertTrue(stored.first?.project.files["main.go"]?.contains("my latest edit") == true)
    }
}
