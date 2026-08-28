import XCTest
@testable import GopherForge

/// Turning a downloaded repository snapshot into something openable.
final class GitHubRepositoryImporterTests: XCTestCase {
    private let reference = GitHubRepositoryReference(
        owner: "golang",
        repository: "example",
        reference: nil
    )
    private let importer = GitHubRepositoryImporter()

    /// GitHub's tarballs put everything under `<repo>-<ref>/`, which the
    /// archive reader strips.
    private func archive(_ files: [String: String]) throws -> Data {
        try ProjectArchive.gzip(ProjectArchive.tar(files: files, root: "example-main"))
    }

    func testAGoRepositoryBecomesAProject() throws {
        let data = try archive([
            "main.go": "package main\n\nfunc main() {}\n",
            "go.mod": "module example\n\ngo 1.24\n",
            "README.md": "# example\n",
        ])

        let project = try importer.project(fromArchive: data, reference: reference)

        XCTAssertEqual(project.name, "example")
        XCTAssertEqual(Set(project.files.keys), ["main.go", "go.mod", "README.md"])
        XCTAssertEqual(project.provenance?.source, .github)
        XCTAssertEqual(project.provenance?.owner, "golang")
    }

    /// The entry file is the one worth opening, which is the program's own
    /// main rather than whatever sorts first.
    func testTheEntryFileIsTheProgramsMain() throws {
        let data = try archive([
            "aardvark/lib.go": "package aardvark\n",
            "cmd/tool/main.go": "package main\n\nfunc main() {}\n",
        ])

        let project = try importer.project(fromArchive: data, reference: reference)

        XCTAssertEqual(project.entryFile, "cmd/tool/main.go")
    }

    /// A library has no main, and still has to open somewhere.
    func testALibraryOpensAtItsFirstGoFile() throws {
        let data = try archive(["greet/greet.go": "package greet\n"])

        let project = try importer.project(fromArchive: data, reference: reference)

        XCTAssertEqual(project.entryFile, "greet/greet.go")
    }

    /// Importing a repository with no Go in it produces a project that cannot
    /// build, so it is refused with a sentence rather than opened.
    func testARepositoryWithNoGoIsRefused() throws {
        let data = try archive(["README.md": "# not go\n"])

        XCTAssertThrowsError(try importer.project(fromArchive: data, reference: reference)) {
            XCTAssertEqual(
                $0 as? GitHubRepositoryImporter.ImportError,
                .noGoSource("golang/example")
            )
        }
    }

    func testSomethingThatIsNotAnArchiveIsRefused() {
        XCTAssertThrowsError(
            try importer.project(fromArchive: Data("not a tarball".utf8), reference: reference)
        ) {
            XCTAssertEqual($0 as? GitHubRepositoryImporter.ImportError, .notAnArchive)
        }
    }

    // MARK: - What is worth keeping

    func testRepositoryFurnitureIsLeftBehind() {
        for path in [
            ".github/workflows/ci.yml",
            ".git/config",
            "internal/testdata/golden.go",
            "vendor/github.com/x/y/z.go",
        ] {
            XCTAssertFalse(
                GitHubRepositoryImporter.isWorthKeeping(path: path),
                "\(path) should not be imported"
            )
        }
    }

    func testSourceAndItsPaperworkAreKept() {
        for path in ["main.go", "go.mod", "go.sum", "README.md", "LICENSE", "Makefile"] {
            XCTAssertTrue(
                GitHubRepositoryImporter.isWorthKeeping(path: path),
                "\(path) should be imported"
            )
        }
    }

    /// A binary named like a document is still a binary, and putting one in a
    /// text view helps nobody.
    func testBinariesAreDropped() {
        for path in ["logo.png", "demo.gif", "tool", "archive.zip"] {
            XCTAssertFalse(
                GitHubRepositoryImporter.isWorthKeeping(path: path),
                "\(path) should not be imported"
            )
        }
    }

    /// Bytes that are not UTF-8 are dropped rather than mangled into
    /// replacement characters, whatever the file is called.
    func testAFileThatIsNotTextIsDropped() throws {
        var files = ["main.go": "package main\n\nfunc main() {}\n"]
        files["notes.txt"] = "fine"
        var data = try ProjectArchive.tar(files: files, root: "example-main")
        // Corrupt the body of notes.txt into invalid UTF-8.
        if let range = data.range(of: Data("fine".utf8)) {
            data.replaceSubrange(range, with: Data([0xFF, 0xFE, 0xFF, 0xFE]))
        }

        let project = try importer.project(
            fromArchive: try ProjectArchive.gzip(data),
            reference: reference
        )

        XCTAssertNil(project.files["notes.txt"])
        XCTAssertNotNil(project.files["main.go"])
    }
}
