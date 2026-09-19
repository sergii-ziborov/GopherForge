import XCTest
@testable import GopherForge

final class GoSourceSnapshotTests: XCTestCase {
    func testASingleFileIsWrappedInAModule() {
        let snapshot = GoSourceSnapshot.singleFile("package main\nfunc main() {}\n")
        XCTAssertEqual(snapshot.packagePattern, ".")
        XCTAssertEqual(snapshot.entryFile, "main.go")
        XCTAssertEqual(snapshot.goFileCount, 1)
        XCTAssertFalse(snapshot.hasTests)
        XCTAssertTrue(snapshot.files["go.mod"]?.contains("module playground") == true)
        XCTAssertTrue(snapshot.files["go.mod"]?.contains("go \(GoLanguage.declaredModuleVersion)") == true)
    }

    func testSourceLinesAreSplitPerFile() {
        let snapshot = GoSourceSnapshot(files: [
            "main.go": "package main\nfunc main() {}\n",
        ])
        XCTAssertEqual(snapshot.sourceLines["main.go"], ["package main", "func main() {}", ""])
    }

    func testHasTestsLooksAtTheFileName() {
        let snapshot = GoSourceSnapshot(files: [
            "main.go": "package main\n",
            "main_test.go": "package main\n",
        ])
        XCTAssertTrue(snapshot.hasTests)
        XCTAssertEqual(snapshot.goFileCount, 2)
    }

    func testAWorkspaceReuseKeyIsPreserved() {
        let snapshot = GoSourceSnapshot(
            files: ["main.go": "package main\n"],
            workspaceReuseKey: "project-1"
        )
        XCTAssertEqual(snapshot.workspaceReuseKey, "project-1")
    }

    func testEqualityIncludesTheReuseKey() {
        let files = ["main.go": "package main\n"]
        XCTAssertNotEqual(
            GoSourceSnapshot(files: files, workspaceReuseKey: "a"),
            GoSourceSnapshot(files: files, workspaceReuseKey: "b")
        )
    }

    func testACustomModuleNameIsHonoured() {
        let snapshot = GoSourceSnapshot.singleFile("package main\n", moduleName: "example.com/x")
        XCTAssertTrue(snapshot.files["go.mod"]?.contains("module example.com/x") == true)
    }
}
