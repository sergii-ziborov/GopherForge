import XCTest
@testable import GopherForge

final class ProjectArchiveRoundTripTests: XCTestCase {
    func testTarThenUntarRestoresFilesUnderTheRoot() throws {
        let files = [
            "go.mod": "module example.com/forge\n",
            "main.go": "package main\nfunc main() {}\n",
            "greet/greet.go": "package greet\n",
        ]
        let tar = try ProjectArchive.tar(files: files, root: "forge")
        let restored = try ProjectArchive.files(fromTar: tar)
        XCTAssertEqual(restored["go.mod"], files["go.mod"])
        XCTAssertEqual(restored["main.go"], files["main.go"])
        XCTAssertEqual(restored["greet/greet.go"], files["greet/greet.go"])
    }

    func testAPathThatDoesNotFitTheHeaderIsRefused() {
        let long = String(repeating: "a", count: 96)
        XCTAssertThrowsError(try ProjectArchive.tar(files: ["x.go": ""], root: long)) { error in
            XCTAssertEqual(error as? ProjectArchive.ArchiveError, .pathTooLong("\(long)/x.go"))
        }
    }

    func testAShortBufferIsNotATar() {
        XCTAssertThrowsError(try ProjectArchive.files(fromTar: Data("short".utf8))) { error in
            XCTAssertEqual(error as? ProjectArchive.ArchiveError, .notATar)
        }
    }

    func testArchiveNamingFollowsTheShareSheet() {
        XCTAssertEqual(ProjectArchiveNaming.archiveName(for: "Worker Pool"), "worker-pool.tar.gz")
        XCTAssertEqual(ProjectArchiveNaming.projectName(fromArchive: ""), "Imported project")
        XCTAssertEqual(
            ProjectArchiveNaming.entryFile(in: ["README.md": "", "notes.txt": ""]),
            "README.md"
        )
    }
}
