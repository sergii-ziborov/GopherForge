import XCTest
@testable import GopherForge

final class GoStandardLibraryIndexTests: XCTestCase {
    func testUnsafeIsAlwaysResolvable() {
        XCTAssertTrue(GoStandardLibraryIndex.compilerProvided.contains("unsafe"))
        XCTAssertTrue(GoStandardLibraryIndex.empty.resolvableImportPaths.contains("unsafe"))
        XCTAssertTrue(GoStandardLibraryIndex.empty.isEmpty)
    }

    func testLoadReadsArchivesRelativeToTheRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "stdlib-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: root.appending(path: "encoding/json", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appending(path: "fmt", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try Data().write(to: root.appending(path: "fmt.a"))
        try Data().write(to: root.appending(path: "encoding/json.a"))
        try Data().write(to: root.appending(path: "notes.txt"))
        defer { try? FileManager.default.removeItem(at: root) }

        let index = GoStandardLibraryIndex.load(packageRoot: root)
        XCTAssertEqual(index.importPaths, ["fmt", "encoding/json"])
        XCTAssertTrue(index.resolvableImportPaths.contains("unsafe"))
        XCTAssertFalse(index.isEmpty)
    }

    func testAMissingRootIsEmpty() {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "stdlib-missing-\(UUID().uuidString)")
        XCTAssertTrue(GoStandardLibraryIndex.load(packageRoot: missing).isEmpty)
    }
}
