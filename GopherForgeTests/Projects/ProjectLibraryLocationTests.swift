import XCTest
@testable import GopherForge

final class ProjectLibraryLocationTests: XCTestCase {
    override func tearDown() {
        ProjectLibraryLocation.forgetChosenFolder()
        super.tearDown()
    }

    func testTheDefaultLibraryIsOnThisDevice() {
        ProjectLibraryLocation.forgetChosenFolder()
        XCTAssertFalse(ProjectLibraryLocation.usesChosenFolder)
        XCTAssertTrue(ProjectLibraryLocation.fileURL().path.hasSuffix("recent-projects.json"))
        XCTAssertTrue(ProjectLibraryLocation.fileURL().path.contains("Application Support")
            || ProjectLibraryLocation.fileURL().path.contains("T/"))
    }

    func testRememberingAFolderPointsTheLibraryThere() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-lib-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        try ProjectLibraryLocation.remember(folder: folder)

        XCTAssertTrue(ProjectLibraryLocation.usesChosenFolder)
        XCTAssertEqual(
            ProjectLibraryLocation.fileURL().standardizedFileURL,
            folder.appending(path: "recent-projects.json").standardizedFileURL
        )
    }

    func testAdoptingAFolderMovesTheLibraryJSON() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-adopt-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folder)
            ProjectLibraryLocation.forgetChosenFolder()
        }

        let store = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-adopt-src-\(UUID().uuidString).json")
        let library = ProjectLibrary(storageURL: store)
        _ = try await library.record(
            project: ProjectTemplate.commandLineTool.project(named: "Moved"),
            lastBuild: nil
        )

        let items = try await library.adoptFolder(folder)
        XCTAssertEqual(items.map(\.project.name), ["Moved"])
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: folder.appending(path: "recent-projects.json").path
            )
        )
    }
}
