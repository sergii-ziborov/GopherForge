import XCTest
@testable import GopherForge

final class GopherForgeProjectTests: XCTestCase {
    func testRenameKeepsFilesAndProvenance() {
        let original = GopherForgeProject(
            name: "Old",
            files: [
                "go.mod": GoLanguage.module("old"),
                "main.go": "package main\nfunc main() {}\n",
                "greet/greet.go": "package greet\n",
                "greet/greet_test.go": "package greet\n",
            ],
            entryFile: "main.go",
            provenance: .files()
        )
        let renamed = original.renamed(to: "New")
        XCTAssertEqual(renamed.name, "New")
        XCTAssertEqual(renamed.files, original.files)
        XCTAssertEqual(renamed.entryFile, "main.go")
        XCTAssertEqual(renamed.provenance?.source, .files)
        XCTAssertEqual(renamed.goFileCount, 3)
        XCTAssertEqual(renamed.testFileCount, 1)
        XCTAssertEqual(renamed.packageDirectories, [".", "greet"])
        XCTAssertEqual(renamed.module?.modulePath, "old")
    }

    func testASnapshotCarriesTheReuseKey() {
        let project = GopherForgeProject(
            name: "Forge",
            files: ["main.go": "package main\n"],
            entryFile: "main.go",
            provenance: nil
        )
        let snapshot = project.snapshot(packagePattern: "./cmd", workspaceReuseKey: "lib-1")
        XCTAssertEqual(snapshot.files, project.files)
        XCTAssertEqual(snapshot.packagePattern, "./cmd")
        XCTAssertEqual(snapshot.workspaceReuseKey, "lib-1")
        XCTAssertEqual(snapshot.entryFile, "main.go")
    }
}
