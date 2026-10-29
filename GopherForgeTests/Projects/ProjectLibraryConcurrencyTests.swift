import XCTest
@testable import GopherForge

final class ProjectLibraryConcurrencyTests: XCTestCase {
    private func project(_ name: String, _ code: String) -> GopherForgeProject {
        GopherForgeProject(name: name, files: ["main.go": code], entryFile: "main.go", provenance: nil)
    }

    func testIndependentWritersPreserveXAndYDespiteBothReadingTheOldDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "library-two-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let a = ProjectLibrary(storageURL: url), b = ProjectLibrary(storageURL: url)
        let x = UUID(), y = UUID()
        _ = try await a.recordSource(id: x, revision: 0, project: project("X", "X0"))
        _ = try await a.recordSource(id: y, revision: 0, project: project("Y", "Y0"))
        _ = try await a.items(); _ = try await b.items()
        _ = try await a.recordSource(id: x, revision: 1, project: project("X", "X1"))
        _ = try await b.recordSource(id: y, revision: 1, project: project("Y", "Y1"))
        let fresh = ProjectLibrary(storageURL: url)
        let saved = try await fresh.items()
        XCTAssertEqual(saved.first { $0.id == x }?.project.files["main.go"], "X1")
        XCTAssertEqual(saved.first { $0.id == y }?.project.files["main.go"], "Y1")
        let reread = try await a.items()
        XCTAssertEqual(reread.first { $0.id == y }?.project.files["main.go"], "Y1")
    }

    func testForkedSourceKeepsBothVersionsInsteadOfChoosingTheHighestLocalCounter() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "library-fork-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let a = ProjectLibrary(storageURL: url), b = ProjectLibrary(storageURL: url)
        let id = UUID()
        _ = try await a.recordSource(id: id, revision: 0, project: project("X", "base"))
        _ = try await a.items(); _ = try await b.items()
        _ = try await a.recordSource(id: id, revision: 20, project: project("X", "A"))
        let copy = try await b.recordSource(id: id, revision: 1, project: project("X", "B"))
        XCTAssertNotEqual(copy.id, id)
        let saved = try await ProjectLibrary(storageURL: url).items()
        XCTAssertEqual(Set(saved.compactMap { $0.project.files["main.go"] }), ["A", "B"])
        XCTAssertEqual(saved.first { $0.id == id }?.project.files["main.go"], "A")
        XCTAssertTrue(copy.project.name.contains("conflict copy"))
    }

    func testEditOfDeletedProjectBecomesARecoveryCopyWithoutResurrectingItsUUID() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "library-delete-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let a = ProjectLibrary(storageURL: url), b = ProjectLibrary(storageURL: url)
        let id = UUID()
        _ = try await a.recordSource(id: id, revision: 0, project: project("X", "base"))
        _ = try await b.items()
        _ = try await a.remove(id: id)
        let recovered = try await b.recordSource(id: id, revision: 1, project: project("X", "edited"))
        XCTAssertNotEqual(recovered.id, id)
        let saved = try await ProjectLibrary(storageURL: url).items()
        XCTAssertFalse(saved.contains { $0.id == id })
        XCTAssertEqual(saved.first?.project.files["main.go"], "edited")
    }

    func testConcurrentTransactionsDoNotDropNewProjects() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "library-parallel-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let projects = (0..<12).map { project("P\($0)", "source \($0)") }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for project in projects {
                group.addTask {
                    _ = try await ProjectLibrary(storageURL: url).record(project: project, lastBuild: nil)
                }
            }
            try await group.waitForAll()
        }
        let saved = try await ProjectLibrary(storageURL: url).items()
        XCTAssertEqual(Set(saved.map(\.project.name)), Set(projects.map(\.name)))
    }

    func testBackupFailureLeavesTheOriginalBytesUntouched() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "library-backup-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let library = ProjectLibrary(storageURL: url)
        let id = UUID()
        _ = try await library.recordSource(id: id, revision: 0, project: project("X", "original"))
        let before = try Data(contentsOf: url)
        let backups = root.appending(path: ".gopherforge-backups")
        try FileManager.default.removeItem(at: backups)
        try Data("blocked".utf8).write(to: backups)
        do { _ = try await library.recordSource(id: id, revision: 1, project: project("X", "new")); XCTFail("must refuse unprotected write") }
        catch { }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testRemovedOrFutureLibraryIsNeverRecreatedAsEmpty() async throws {
        for remove in [true, false] {
            let root = FileManager.default.temporaryDirectory.appending(path: "library-external-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let url = root.appending(path: "projects.json")
            let library = ProjectLibrary(storageURL: url)
            let id = UUID()
            _ = try await library.recordSource(id: id, revision: 0, project: project("X", "original"))
            if remove { try FileManager.default.removeItem(at: url) }
            else { try Data(#"{"schemaVersion":99,"items":[]}"#.utf8).write(to: url) }
            do { _ = try await library.recordSource(id: id, revision: 1, project: project("X", "new")); XCTFail("must refuse changed document") }
            catch { }
            if remove { XCTAssertFalse(FileManager.default.fileExists(atPath: url.path)) }
            else { XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), #"{"schemaVersion":99,"items":[]}"#) }
        }
    }
}

@MainActor
final class WorkspaceLibraryConflictTests: XCTestCase {
    func testTwoEditorsKeepTheirOwnSourceAndContinueSavingAfterAConflict() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "workspace-fork-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let first = ProjectLibrary(storageURL: url), second = ProjectLibrary(storageURL: url)
        let id = UUID(), original = ProjectTemplate.commandLineTool.project(named: "Original")
        let item = try await first.recordSource(id: id, revision: 0, project: original)
        let a = WorkspaceModel(library: first), b = WorkspaceModel(library: second)
        XCTAssertTrue(a.open(item)); XCTAssertTrue(b.open(item))
        a.updateEditorText("package main\n// A\n"); await a.flush()
        b.updateEditorText("package main\n// B\n"); await b.flush()
        let recoveredID = try XCTUnwrap(b.projectID)
        XCTAssertNotEqual(recoveredID, id)
        XCTAssertNotNil(b.persistenceNotice)
        XCTAssertEqual(b.editorText, "package main\n// B\n")
        b.updateEditorText("package main\n// B continues\n"); await b.flush()
        let saved = try await ProjectLibrary(storageURL: url).items()
        XCTAssertEqual(saved.first { $0.id == id }?.project.files["main.go"], "package main\n// A\n")
        XCTAssertEqual(saved.first { $0.id == recoveredID }?.project.files["main.go"], "package main\n// B continues\n")
        XCTAssertFalse(b.hasUnsavedChanges)
    }
    func testNoopSourceUpdatesDoNotRollBackTheEditorsRevision() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "workspace-revision-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: url))
        workspace.open(ProjectTemplate.commandLineTool.project(named: "Source"))
        await workspace.libraryUpdated()
        for _ in 0..<12 { workspace.replaceFiles(with: try XCTUnwrap(workspace.project?.files)) }
        let revision = workspace.sourceRevision
        await workspace.flush()
        XCTAssertGreaterThanOrEqual(workspace.sourceRevision, revision)
        workspace.updateEditorText("package main\n// after noop updates\n")
        await workspace.flush()
        let saved = try await ProjectLibrary(storageURL: url).items()
        XCTAssertEqual(saved.first?.project.files["main.go"], "package main\n// after noop updates\n")
    }

}

@MainActor
final class WorkspaceUnicodeTests: XCTestCase {
    func testCanonicallyEquivalentUnicodeEditsKeepTheirExactSourceBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "workspace-unicode-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let workspace = WorkspaceModel(library: ProjectLibrary(storageURL: url))
        workspace.open(ProjectTemplate.commandLineTool.project(named: "Unicode"))
        await workspace.libraryUpdated()
        let composed = "package main\nvar text = \"\u{00e9}\"\n"
        let decomposed = "package main\nvar text = \"e\u{0301}\"\n"
        XCTAssertEqual(composed, decomposed)
        XCTAssertNotEqual(Data(composed.utf8), Data(decomposed.utf8))
        workspace.updateEditorText(composed); await workspace.flush()
        workspace.updateEditorText(decomposed); await workspace.flush()
        let saved = try await ProjectLibrary(storageURL: url).items()
        let actual = try XCTUnwrap(saved.first?.project.files["main.go"])
        XCTAssertEqual(Data(actual.utf8), Data(decomposed.utf8))
    }
}
