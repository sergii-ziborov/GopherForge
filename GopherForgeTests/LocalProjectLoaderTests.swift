import XCTest
@testable import GopherForge

final class LocalProjectLoaderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testReadsAModuleAndItsPackages() throws {
        try write("go.mod", "module example.com/forge\n\ngo 1.27\n")
        try write("main.go", "package main\n\nfunc main() {}\n")
        try write("internal/build/build.go", "package build\n")

        let project = try LocalProjectLoader().load(from: root)

        XCTAssertEqual(project.module?.modulePath, "example.com/forge")
        XCTAssertEqual(project.entryFile, "main.go")
        XCTAssertEqual(project.packageDirectories, [".", "internal/build"])
        XCTAssertEqual(project.provenance?.source, .files)
    }

    /// A checkout usually holds the module one directory down, and opening the
    /// checkout root would give a file tree the build does not agree with.
    func testOpensTheModuleRootRatherThanTheCheckoutRoot() throws {
        try write("app/go.mod", "module example.com/app\n\ngo 1.27\n")
        try write("app/main.go", "package main\n\nfunc main() {}\n")
        try write("README.md", "# checkout\n")

        let project = try LocalProjectLoader().load(from: root)

        XCTAssertEqual(project.name, "app")
        XCTAssertNotNil(project.files["main.go"])
        XCTAssertNil(project.files["app/main.go"])
    }

    func testSkipsFilesItCannotUsefullyOpen() throws {
        try write("go.mod", "module m\n\ngo 1.27\n")
        try write("main.go", "package main\n\nfunc main() {}\n")
        try write("logo.png", "not really a png")

        let project = try LocalProjectLoader().load(from: root)

        XCTAssertNil(project.files["logo.png"])
    }

    func testAFolderWithNoGoFilesIsRejected() throws {
        try write("README.md", "# nothing to build\n")
        XCTAssertThrowsError(try LocalProjectLoader().load(from: root)) { error in
            XCTAssertEqual(error as? LocalProjectLoader.LoadError, .noGoFiles)
        }
    }

    func testTooManyFilesIsRejectedRatherThanTruncated() throws {
        try write("go.mod", "module m\n\ngo 1.27\n")
        for index in 0..<12 {
            try write("pkg\(index).go", "package main\n")
        }
        let loader = LocalProjectLoader(limits: {
            var limits = LocalProjectLoader.Limits.standard
            limits.maximumFileCount = 5
            return limits
        }())

        XCTAssertThrowsError(try loader.load(from: root)) { error in
            XCTAssertEqual(error as? LocalProjectLoader.LoadError, .tooManyFiles(5))
        }
    }

    func testProjectPackageRoundTrips() throws {
        try write("go.mod", "module example.com/forge\n\ngo 1.27\n")
        try write("main.go", "package main\n\nfunc main() {}\n")
        let project = try LocalProjectLoader().load(from: root)

        let exported = root.appending(path: "Exported.gopherforgeproject", directoryHint: .isDirectory)
        try GopherForgeProjectDocument.write(project, to: exported)
        let reopened = try GopherForgeProjectDocument.read(from: exported)

        XCTAssertEqual(reopened.name, project.name)
        XCTAssertEqual(reopened.entryFile, project.entryFile)
        XCTAssertEqual(reopened.files["main.go"], project.files["main.go"])
        XCTAssertNil(reopened.files["gopherforge.json"])
    }

    private func write(_ relativePath: String, _ contents: String) throws {
        let url = root.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
    }
}
