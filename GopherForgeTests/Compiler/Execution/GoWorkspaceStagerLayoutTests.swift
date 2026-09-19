import XCTest
@testable import GopherForge

final class GoWorkspaceStagerLayoutTests: XCTestCase {
    func testGuestPathsResolveOnlyUnderPreopenedRoots() throws {
        let stager = GoWorkspaceStager()
        let layout = try stager.createLayout(named: "guest-map")
        defer { stager.remove(layout) }

        XCTAssertEqual(layout.hostURL(forGuestPath: "/work"), layout.work)
        XCTAssertEqual(layout.hostURL(forGuestPath: "/tmp"), layout.temp)
        XCTAssertEqual(layout.hostURL(forGuestPath: "/cache"), layout.cache)
        XCTAssertEqual(
            layout.hostURL(forGuestPath: "/work/main.go")?.lastPathComponent,
            "main.go"
        )
        XCTAssertNil(layout.hostURL(forGuestPath: "/goroot/pkg/fmt.a"))
        XCTAssertNil(layout.hostURL(forGuestPath: "/work/../escape"))
        XCTAssertNil(layout.hostURL(forGuestPath: "/etc/passwd"))
    }

    func testAPersistentRootKeepsAStableWorkTree() throws {
        let stager = GoWorkspaceStager()
        let root = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-layout-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try stager.createLayout(named: "a", persistentRoot: root)
        let second = try stager.createLayout(named: "b", persistentRoot: root)
        XCTAssertEqual(first.work.standardizedFileURL, second.work.standardizedFileURL)
        XCTAssertNotEqual(first.jobRoot, second.jobRoot)
        XCTAssertTrue(GoWorkspaceStager.persistentRootURL(for: "proj").path.contains("GopherForgeWork"))
        XCTAssertEqual(GoWorkspaceStager.digest("abc").count, 32)
    }

    func testResolveRejectsDotDotAndAbsolutePaths() {
        let root = FileManager.default.temporaryDirectory
        XCTAssertNil(GoWorkspaceStager.resolve(relativePath: "../x", under: root))
        XCTAssertNil(GoWorkspaceStager.resolve(relativePath: "/tmp/x", under: root))
        XCTAssertNil(GoWorkspaceStager.resolve(relativePath: "a/./b", under: root))
        XCTAssertEqual(
            GoWorkspaceStager.resolve(relativePath: "greet/greet.go", under: root)?.lastPathComponent,
            "greet.go"
        )
    }
}
