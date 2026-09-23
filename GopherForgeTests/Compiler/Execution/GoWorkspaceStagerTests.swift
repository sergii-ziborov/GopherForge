import XCTest
@testable import GopherForge

final class GoWorkspaceStagerTests: XCTestCase {
    func testASecondStageSkipsUnchangedFiles() throws {
        let stager = GoWorkspaceStager()
        let layout = try stager.createLayout(named: "stage-skip")
        defer { stager.remove(layout) }

        try stager.stage(files: ["main.go": "package main\n", "go.mod": "module p\n"], into: layout.work)
        let main = layout.work.appending(path: "main.go")
        let first = try FileManager.default.attributesOfItem(atPath: main.path)[.modificationDate] as? Date
        try stager.stage(files: ["main.go": "package main\n", "go.mod": "module p\n"], into: layout.work)
        let second = try FileManager.default.attributesOfItem(atPath: main.path)[.modificationDate] as? Date

        XCTAssertEqual(first, second)
    }

    func testChangingOneFileDoesNotRewriteTheOthers() throws {
        let stager = GoWorkspaceStager()
        let layout = try stager.createLayout(named: "stage-one")
        defer { stager.remove(layout) }

        let vendor = String(repeating: "package vendor\n", count: 40)
        try stager.stage(
            files: ["main.go": "package main\n", "vendor/lib.go": vendor],
            into: layout.work
        )
        let vendorURL = layout.work.appending(path: "vendor/lib.go")
        let before = try FileManager.default.attributesOfItem(atPath: vendorURL.path)[.modificationDate] as? Date
        try stager.stage(
            files: ["main.go": "package main\n\nfunc main() {}\n", "vendor/lib.go": vendor],
            into: layout.work
        )
        let after = try FileManager.default.attributesOfItem(atPath: vendorURL.path)[.modificationDate] as? Date

        XCTAssertEqual(before, after)
        XCTAssertTrue(
            (try String(contentsOf: layout.work.appending(path: "main.go"), encoding: .utf8))
                .contains("func main")
        )
    }

    func testStagingDropsAFileThatLeftTheProject() throws {
        let stager = GoWorkspaceStager()
        let layout = try stager.createLayout(named: "stage-prune")
        defer { stager.remove(layout) }

        try stager.stage(
            files: ["main.go": "package main\n", "gone.go": "package main\n"],
            into: layout.work
        )
        try stager.stage(files: ["main.go": "package main\n"], into: layout.work)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: layout.work.appending(path: "gone.go").path)
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: layout.work.appending(path: "main.go").path)
        )
    }

    func testStagingDropsAnEmptyFolderMarkerWhenFolderIsDeleted() throws {
        let stager = GoWorkspaceStager()
        let layout = try stager.createLayout(named: "stage-folder-\(UUID().uuidString)")
        defer { stager.remove(layout) }
        try stager.stage(files: [
            "main.go": "package main\n",
            "empty/.gopherforge-folder": "",
        ], into: layout.work)
        try stager.stage(files: ["main.go": "package main\n"], into: layout.work)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: layout.work.appending(path: "empty/.gopherforge-folder").path
        ))
    }

    func testPersistentWorkAndTempSurviveJobCleanup() throws {
        let stager = GoWorkspaceStager()
        let root = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-persistent-\(UUID().uuidString)", directoryHint: .isDirectory)
        let layout = try stager.createLayout(named: "persist", persistentRoot: root)
        try stager.stage(files: ["main.go": "package main\n"], into: layout.work)
        try Data("archive".utf8).write(to: layout.temp.appending(path: "pkg.a"))
        stager.remove(layout)

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "work/main.go").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "tmp/pkg.a").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: layout.jobRoot.path))
        try? FileManager.default.removeItem(at: root)
    }

    func testARelativeEscapeIsRejected() throws {
        let stager = GoWorkspaceStager()
        let layout = try stager.createLayout(named: "escape")
        defer { stager.remove(layout) }
        XCTAssertThrowsError(
            try stager.stage(files: ["../x.go": "package main\n"], into: layout.work)
        ) { error in
            XCTAssertEqual(error as? GoWorkspaceStager.StagingError, .invalidPath("../x.go"))
        }
    }

    func testAnAbsolutePathIsRejected() {
        XCTAssertNil(GoWorkspaceStager.resolve(relativePath: "/tmp/x.go", under: FileManager.default.temporaryDirectory))
        XCTAssertNil(GoWorkspaceStager.resolve(relativePath: "foo/../bar.go", under: FileManager.default.temporaryDirectory))
        XCTAssertNil(GoWorkspaceStager.resolve(relativePath: "", under: FileManager.default.temporaryDirectory))
        XCTAssertNil(GoWorkspaceStager.resolve(relativePath: "foo//bar.go", under: FileManager.default.temporaryDirectory))
    }

    func testASafeNestedPathResolves() throws {
        let root = FileManager.default.temporaryDirectory
        let url = try XCTUnwrap(GoWorkspaceStager.resolve(relativePath: "cmd/one/main.go", under: root))
        XCTAssertTrue(url.path.hasSuffix("cmd/one/main.go"))
    }

    func testDigestIsStableAndSensitive() {
        XCTAssertEqual(GoWorkspaceStager.digest("package main\n"), GoWorkspaceStager.digest("package main\n"))
        XCTAssertNotEqual(GoWorkspaceStager.digest("package main\n"), GoWorkspaceStager.digest("package main\n\n"))
        XCTAssertEqual(GoWorkspaceStager.digest("x").count, 32)
    }
}
