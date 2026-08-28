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
        XCTAssertTrue(ProjectFileSearch.results(query: "", in: files).isEmpty)
        XCTAssertTrue(ProjectFileSearch.results(query: "   ", in: files).isEmpty)
    }

    /// The bug this replaced: `main.go` appeared once for its name and again
    /// for every line containing "main", so the sidebar looked like it was
    /// stuttering. One file is one result however many ways it matched.
    func testAFileThatMatchesByNameAndContentIsListedOnce() throws {
        let results = ProjectFileSearch.results(query: "main", in: files)

        XCTAssertEqual(results.filter { $0.path == "main.go" }.count, 1)
        let mainResult = try XCTUnwrap(results.first { $0.path == "main.go" })
        XCTAssertTrue(mainResult.matchesName)
        XCTAssertFalse(mainResult.lines.isEmpty, "its lines should hang off the file")
    }

    /// A file whose name matches is almost always what was meant, so it is
    /// listed before files that merely mention the word.
    func testNameMatchesComeFirst() {
        let results = ProjectFileSearch.results(query: "greet", in: files)

        XCTAssertEqual(results.first?.path, "greet/greet.go")
        XCTAssertEqual(results.first?.matchesName, true)
    }

    func testContentMatchesCarryTheirLine() {
        let results = ProjectFileSearch.results(query: "Println", in: files)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.path, "main.go")
        XCTAssertEqual(results.first?.matchesName, false)
        XCTAssertEqual(results.first?.lines.first?.number, 6)
        XCTAssertEqual(results.first?.lines.first?.snippet, "fmt.Println(\"hello\")")
    }

    func testSearchIsCaseInsensitive() {
        XCTAssertFalse(ProjectFileSearch.results(query: "PRINTLN", in: files).isEmpty)
        XCTAssertFalse(ProjectFileSearch.results(query: "MAIN.GO", in: files).isEmpty)
    }

    func testAQueryInTwoFilesFindsBoth() {
        let results = ProjectFileSearch.results(query: "hello", in: files)

        XCTAssertEqual(Set(results.map(\.path)), ["main.go", "greet/greet.go"])
    }

    /// One letter matches everything, so only names are searched until the
    /// query is worth searching content for.
    func testASingleLetterSearchesNamesOnly() {
        let results = ProjectFileSearch.results(query: "m", in: files)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(
            results.allSatisfy { $0.matchesName && $0.lines.isEmpty },
            "a one-letter query should not report content hits"
        )
    }

    func testOneFileCannotFloodTheResults() {
        let crowded = ["big.go": Array(repeating: "x := hello", count: 50).joined(separator: "\n")]
        let results = ProjectFileSearch.results(query: "hello", in: crowded)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.lines.count, ProjectFileSearch.maximumLinesPerFile)
        // Capped, and it says so rather than looking complete.
        XCTAssertEqual(
            results.first?.additionalLines,
            50 - ProjectFileSearch.maximumLinesPerFile
        )
    }

    func testALongLineIsShortenedForTheRow() {
        let long = String(repeating: "a", count: 200)
        let snippet = ProjectFileSearch.snippet(of: "  \(long)  ")

        XCTAssertTrue(snippet.hasSuffix("\u{2026}"))
        XCTAssertLessThan(snippet.count, long.count)
    }

    // MARK: - Marking what matched

    func testEveryOccurrenceIsMarked() {
        let ranges = ProjectFileSearch.ranges(of: "go", in: "go go gopher")

        XCTAssertEqual(ranges.count, 3)
    }

    func testMarkingIsCaseInsensitiveLikeTheSearch() {
        let ranges = ProjectFileSearch.ranges(of: "MAIN", in: "func main() { main() }")

        XCTAssertEqual(ranges.count, 2)
    }

    /// Nothing is marked for a query that found nothing, so an empty search box
    /// never paints the file yellow.
    func testAnEmptyQueryMarksNothing() {
        XCTAssertTrue(ProjectFileSearch.ranges(of: "", in: "package main").isEmpty)
        XCTAssertTrue(ProjectFileSearch.ranges(of: "  ", in: "package main").isEmpty)
    }
}

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
