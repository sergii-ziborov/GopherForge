import XCTest
@testable import GopherForge

/// Keeping, finding and filing projects.
///
/// The bug the first of these was written for: the library kept the ten most
/// recent projects and dropped the rest. That is a reasonable rule for a strip
/// of recents and a destructive one for the only place a project exists — the
/// eleventh project someone made deleted the first, silently, on open.
final class ProjectLibraryTests: XCTestCase {
    private var storageURL: URL!
    private var library: ProjectLibrary!

    override func setUpWithError() throws {
        storageURL = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-tests-\(UUID().uuidString)")
            .appending(path: "projects.json")
        library = ProjectLibrary(storageURL: storageURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storageURL.deletingLastPathComponent())
    }

    private func project(
        named name: String,
        files: [String: String] = ["main.go": "package main\n"]
    ) -> GopherForgeProject {
        GopherForgeProject(
            name: name,
            files: files,
            entryFile: "main.go",
            provenance: .template()
        )
    }

    func testNothingIsEvicted() async throws {
        for index in 0..<25 {
            _ = try await library.record(project: project(named: "project-\(index)"), lastBuild: nil)
        }

        let items = try await library.items()
        XCTAssertEqual(items.count, 25, "every project should still be there")
        XCTAssertTrue(
            items.contains { $0.project.name == "project-0" },
            "the first project should survive the twenty-fifth"
        )
    }

    func testTwoProjectsWithTheSameNameKeepIndependentSource() async throws {
        _ = try await library.record(
            project: project(named: "same", files: ["main.go": "package main\n// first\n"]),
            lastBuild: nil
        )
        _ = try await library.record(
            project: project(named: "same", files: ["main.go": "package main\n// second\n"]),
            lastBuild: nil
        )

        let items = try await library.items()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(Set(items.compactMap { $0.project.files["main.go"] }).count, 2)
    }

    func testDuplicatingCreatesAnIndependentNamedCopyAndKeepsItsFiling() async throws {
        _ = try await library.record(
            project: project(named: "original", files: ["main.go": "package main\n// source\n"]),
            lastBuild: nil
        )
        let recorded = try await library.items()
        let original = try XCTUnwrap(recorded.first)
        _ = try await library.update(
            id: original.id,
            folder: "Experiments",
            tags: ["go"],
            isFavorite: true,
            summary: "A useful base"
        )

        let duplicated = try await library.duplicate(id: original.id, named: "working copy")
        let copy = try XCTUnwrap(duplicated)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.project.name, "working copy")
        XCTAssertEqual(copy.project.files, original.project.files)
        XCTAssertEqual(copy.folder, "Experiments")
        XCTAssertEqual(copy.tags, ["go"])
        XCTAssertEqual(copy.summary, "A useful base")
        XCTAssertFalse(copy.favorite)
        XCTAssertNil(copy.lastBuild)

        _ = try await library.recordSource(
            id: copy.id,
            revision: 1,
            project: project(named: "working copy", files: ["main.go": "package main\n// changed\n"])
        )
        let storedOriginal = try await library.project(id: original.id)
        let unchanged = try XCTUnwrap(storedOriginal)
        XCTAssertEqual(unchanged.project.files["main.go"], "package main\n// source\n")
    }

    func testCopyNameMakesRepeatedDuplicatesReadable() {
        XCTAssertEqual(
            ProjectLibraryItem.suggestedCopyName(
                of: "Server",
                existingNames: ["Server", "Server copy", "server COPY 2"]
            ),
            "Server copy 3"
        )
    }

    func testReopeningTheSameProjectUpdatesItRatherThanDuplicating() async throws {
        let id = UUID()
        _ = try await library.recordSource(id: id, revision: 0, project: project(named: "same"))
        _ = try await library.recordSource(
            id: id,
            revision: 1,
            project: project(named: "same", files: ["main.go": "package main\n\n// edited\n"])
        )

        let items = try await library.items()
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(
            items[0].project.files["main.go"]?.contains("edited") == true,
            "the entry should carry the newer contents"
        )
    }

    func testSearchLooksAtName_folder_tagsAndFileNames() async throws {
        _ = try await library.record(project: project(named: "wire-protocol"), lastBuild: nil)
        _ = try await library.record(
            project: project(named: "toy", files: ["main.go": "", "parser.go": ""]),
            lastBuild: nil
        )
        let items = try await library.items()
        let toy = try XCTUnwrap(items.first { $0.project.name == "toy" })
        _ = try await library.update(id: toy.id, folder: "Experiments", tags: ["wip"])

        let filed = try await library.items()
        let byName = filed.filter { $0.matches("wire") }
        let byFolder = filed.filter { $0.matches("experiments") }
        let byTag = filed.filter { $0.matches("wip") }
        let byFile = filed.filter { $0.matches("parser.go") }

        XCTAssertEqual(byName.map(\.project.name), ["wire-protocol"])
        XCTAssertEqual(byFolder.map(\.project.name), ["toy"])
        XCTAssertEqual(byTag.map(\.project.name), ["toy"])
        XCTAssertEqual(
            byFile.map(\.project.name), ["toy"],
            "a file name is often what someone remembers about a project"
        )
    }

    func testAnEmptyFolderMeansUnfiledRatherThanAFolderWithNoName() async throws {
        _ = try await library.record(project: project(named: "loose"), lastBuild: nil)
        let stored = try await library.items()
        let id = try XCTUnwrap(stored.first).id

        _ = try await library.update(id: id, folder: "   ")

        let found = try await library.project(id: id)
        let item = try XCTUnwrap(found)
        XCTAssertNil(item.folder)
        XCTAssertEqual(item.folderLabel, ProjectLibraryItem.looseFolder)
    }

    func testTagsAreTrimmedLowercasedAndDeduplicated() {
        XCTAssertEqual(
            ProjectLibraryItem.normalizedTags(" Go , parser,go ,, PARSER "),
            ["go", "parser"],
            "two tags differing only in case are one tag"
        )
    }

    func testRenamingKeepsTheFilesAndTheEntryFile() async throws {
        _ = try await library.record(
            project: project(named: "before", files: ["main.go": "package main\n"]),
            lastBuild: nil
        )
        let stored = try await library.items()
        let id = try XCTUnwrap(stored.first).id

        _ = try await library.update(id: id, name: "after")

        let found = try await library.project(id: id)
        let item = try XCTUnwrap(found)
        XCTAssertEqual(item.project.name, "after")
        XCTAssertEqual(item.project.entryFile, "main.go")
        XCTAssertEqual(item.project.files["main.go"], "package main\n")
    }

    func testAnEmptyNameIsRefusedRatherThanApplied() async throws {
        _ = try await library.record(project: project(named: "keeps-its-name"), lastBuild: nil)
        let stored = try await library.items()
        let id = try XCTUnwrap(stored.first).id

        _ = try await library.update(id: id, name: "   ")

        let found = try await library.project(id: id)
        let item = try XCTUnwrap(found)
        XCTAssertEqual(
            item.project.name, "keeps-its-name",
            "a project with no name is one nobody can find again"
        )
    }

    func testFoldersListsEachOneOnceAndNamesTheLooseBucket() async throws {
        _ = try await library.record(project: project(named: "a"), lastBuild: nil)
        _ = try await library.record(project: project(named: "b"), lastBuild: nil)
        _ = try await library.record(project: project(named: "c"), lastBuild: nil)
        let items = try await library.items()
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.project.name, $0.id) })

        let a = try XCTUnwrap(byName["a"])
        let b = try XCTUnwrap(byName["b"])
        _ = try await library.move(id: a, toFolder: "Work")
        _ = try await library.move(id: b, toFolder: "Work")

        let folders = try await library.folders()
        XCTAssertEqual(folders, [ProjectLibraryItem.looseFolder, "Work"])
    }

    func testStarringSurvivesReopeningTheProject() async throws {
        _ = try await library.record(project: project(named: "starred"), lastBuild: nil)
        let stored = try await library.items()
        let id = try XCTUnwrap(stored.first).id
        _ = try await library.setFavorite(id: id, true)

        // Opening it again records it, which used to overwrite the whole entry.
        _ = try await library.recordSource(id: id, revision: 1, project: project(named: "starred"))

        let found = try await library.project(id: id)
        let item = try XCTUnwrap(found)
        XCTAssertTrue(item.favorite, "reopening a project should not unstar it")
        let remaining = try await library.items()
        XCTAssertEqual(remaining.count, 1)
    }

    func testOlderSourceSaveCannotRollBackANewerRevision() async throws {
        let id = UUID()
        _ = try await library.recordSource(id: id, revision: 0, project: project(named: "same"))
        _ = try await library.recordSource(
            id: id, revision: 2,
            project: project(named: "same", files: ["main.go": "package main\n// B\n"])
        )
        _ = try await library.recordSource(
            id: id, revision: 1,
            project: project(named: "same", files: ["main.go": "package main\n// A\n"])
        )
        let stored = try await library.project(id: id)
        XCTAssertEqual(stored?.project.files["main.go"], "package main\n// B\n")
        XCTAssertEqual(stored?.sourceRevision, 2)
    }

    func testBuildResultCannotReplaceSourceEditedAfterBuildStarted() async throws {
        let id = UUID()
        let first = project(named: "build", files: ["main.go": "package main\n// A\n"])
        let second = project(named: "build", files: ["main.go": "package main\n// B\n"])
        _ = try await library.recordSource(id: id, revision: 0, project: first)
        _ = try await library.recordSource(id: id, revision: 1, project: second)
        let result = CompilationResult(
            succeeded: true, phase: .build, exitCode: 0, diagnostics: [],
            stdout: "", stderr: "", duration: .zero, detail: "built A"
        )
        try await library.recordBuild(id: id, result: ProjectBuildRecord(result: result))
        let stored = try await library.project(id: id)
        XCTAssertEqual(stored?.project.files["main.go"], second.files["main.go"])
        XCTAssertEqual(stored?.sourceRevision, 1)
        XCTAssertNotNil(stored?.lastBuild)
    }

    func testRenameAndFilingSurviveSourceSave() async throws {
        let id = UUID()
        _ = try await library.recordSource(id: id, revision: 0, project: project(named: "before"))
        _ = try await library.update(id: id, name: "after", folder: "Work", tags: ["go"], isFavorite: true)
        let renamedItem = try await library.project(id: id)
        let renamed = try XCTUnwrap(renamedItem)
        _ = try await library.recordSource(
            id: id, revision: 1,
            project: GopherForgeProject(
                name: "before", // stale editor snapshot must not undo the library rename
                files: ["main.go": "package main\n// new\n"],
                entryFile: renamed.project.entryFile,
                provenance: renamed.project.provenance
            )
        )
        let storedItem = try await library.project(id: id)
        let stored = try XCTUnwrap(storedItem)
        XCTAssertEqual(stored.project.name, "after")
        XCTAssertEqual(stored.folder, "Work")
        XCTAssertEqual(stored.tags, ["go"])
        XCTAssertTrue(stored.favorite)
    }

    /// A library written before folders existed must still open.
    func testADocumentWrittenBeforeFilingExistedStillDecodes() async throws {
        let legacy = """
        {
          "items" : [
            {
              "id" : "\(UUID().uuidString)",
              "lastOpenedAt" : "2026-08-01T10:00:00Z",
              "project" : {
                "entryFile" : "main.go",
                "files" : { "main.go" : "package main\\n" },
                "name" : "old"
              }
            }
          ]
        }
        """
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(legacy.utf8).write(to: storageURL)

        let reopened = ProjectLibrary(storageURL: storageURL)
        let items = try await reopened.items()
        XCTAssertEqual(items.map(\.project.name), ["old"])
        XCTAssertNil(items[0].sourceRevision)
        XCTAssertFalse(items[0].favorite)
        XCTAssertEqual(items[0].folderLabel, ProjectLibraryItem.looseFolder)
    }

    func testTheHomeScreenKeepsFiveRecents() {
        XCTAssertEqual(ProjectHomeLimits.recentCount, 5)
        let ids = (0..<8).map { _ in UUID() }
        XCTAssertEqual(Array(ids.prefix(ProjectHomeLimits.recentCount)).count, 5)
    }
}
