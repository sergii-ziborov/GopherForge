import XCTest
@testable import GopherForge

/// Finding a file by its name, or by something inside it.
final class ProjectFileSearchTests: XCTestCase {
    private let files: [String: String] = [
        "main.go": "package main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"hello\")\n}\n",
        "greet/greet.go": "package greet\n\nfunc Message() string {\n\treturn \"hello there\"\n}\n",
        "go.mod": "module playground\n\ngo 1.24\n",
    ]

    func testAnEmptyQueryFindsNothing() {
        XCTAssertTrue(ProjectFileSearch.matches(query: "", in: files).isEmpty)
        XCTAssertTrue(ProjectFileSearch.matches(query: "   ", in: files).isEmpty)
    }

    /// A file whose name matches is almost always what was meant, so burying it
    /// under content hits from elsewhere would be wrong.
    func testNameMatchesComeFirst() {
        let matches = ProjectFileSearch.matches(query: "greet", in: files)

        XCTAssertEqual(matches.first?.path, "greet/greet.go")
        XCTAssertEqual(matches.first?.kind, .name)
    }

    func testContentMatchesCarryTheirLine() {
        let matches = ProjectFileSearch.matches(query: "Println", in: files)
        let hit = try? XCTUnwrap(matches.first)

        XCTAssertEqual(hit?.path, "main.go")
        XCTAssertEqual(hit?.lineNumber, 6)
        if case let .content(_, snippet) = hit?.kind {
            XCTAssertEqual(snippet, "fmt.Println(\"hello\")", "the snippet should be the trimmed line")
        } else {
            XCTFail("expected a content match")
        }
    }

    func testSearchIsCaseInsensitive() {
        XCTAssertFalse(ProjectFileSearch.matches(query: "PACKAGE MAIN", in: files).isEmpty)
        XCTAssertFalse(ProjectFileSearch.matches(query: "MAIN.GO", in: files).isEmpty)
    }

    func testAQueryInTwoFilesFindsBoth() {
        let paths = Set(ProjectFileSearch.matches(query: "hello", in: files).map(\.path))

        XCTAssertEqual(paths, ["main.go", "greet/greet.go"])
    }

    /// One letter matches everything and tells the reader nothing, so content
    /// is only searched once the query is worth searching for.
    func testASingleLetterSearchesNamesOnly() {
        let matches = ProjectFileSearch.matches(query: "m", in: files)

        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.allSatisfy { $0.kind == .name })
    }

    /// One enormous file must not be able to fill the whole list.
    func testOneFileCannotFloodTheResults() {
        let flooded = ["big.go": String(repeating: "// needle\n", count: 500)]
        let matches = ProjectFileSearch.matches(query: "needle", in: flooded)

        XCTAssertLessThanOrEqual(matches.count, ProjectFileSearch.maximumMatchesPerFile)
    }

    func testALongLineIsShortenedForTheRow() {
        let line = "\t" + String(repeating: "x", count: 200)
        let snippet = ProjectFileSearch.snippet(of: line)

        XCTAssertLessThanOrEqual(snippet.count, 71)
        XCTAssertTrue(snippet.hasSuffix("…"))
    }
}

/// Names for exported archives and the projects they come back as.
final class ProjectArchiveNamingTests: XCTestCase {
    func testAProjectNameBecomesASafeDirectory() {
        XCTAssertEqual(ProjectArchiveNaming.rootDirectory(for: "Worker Pool"), "worker-pool")
        XCTAssertEqual(ProjectArchiveNaming.rootDirectory(for: "a/b:c"), "a-b-c")
        XCTAssertEqual(ProjectArchiveNaming.rootDirectory(for: ""), "gopherforge-project")
        XCTAssertEqual(ProjectArchiveNaming.rootDirectory(for: "..."), "gopherforge-project")
    }

    func testAnArchiveOpensUnderItsOwnName() {
        XCTAssertEqual(ProjectArchiveNaming.projectName(fromArchive: "worker-pool.tar.gz"), "worker-pool")
        XCTAssertEqual(ProjectArchiveNaming.projectName(fromArchive: "thing.tgz"), "thing")
        XCTAssertEqual(ProjectArchiveNaming.projectName(fromArchive: "plain"), "plain")
    }

    func testTheEntryFileIsTheOneWorthOpening() {
        XCTAssertEqual(
            ProjectArchiveNaming.entryFile(in: ["go.mod": "", "main.go": "", "a.go": ""]),
            "main.go"
        )
        XCTAssertEqual(
            ProjectArchiveNaming.entryFile(in: ["go.mod": "", "cmd/tool/main.go": ""]),
            "cmd/tool/main.go"
        )
        XCTAssertEqual(
            ProjectArchiveNaming.entryFile(in: ["go.mod": "", "greet.go": ""]),
            "greet.go",
            "a library has no main, and go.mod is not what to open"
        )
    }
}
