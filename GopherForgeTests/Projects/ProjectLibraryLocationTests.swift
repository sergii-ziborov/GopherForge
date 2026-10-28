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
    func testOpeningAnExistingLibraryPreservesBothDocuments() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "library-open-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "source.json")
        let folder = root.appending(path: "destination")
        let destination = folder.appending(path: "recent-projects.json")
        let a = ProjectLibrary(storageURL: destination)
        let b = ProjectLibrary(storageURL: source)
        _ = try await a.record(project: ProjectTemplate.commandLineTool.project(named: "KeepA"), lastBuild: nil)
        _ = try await b.record(project: ProjectTemplate.commandLineTool.project(named: "KeepB"), lastBuild: nil)
        let beforeA = try Data(contentsOf: destination), beforeB = try Data(contentsOf: source)
        let opened = try await b.adoptFolder(folder)
        XCTAssertEqual(opened.map(\.project.name), ["KeepA"])
        XCTAssertEqual(try Data(contentsOf: destination), beforeA)
        XCTAssertEqual(try Data(contentsOf: source), beforeB)
    }

    func testInvalidAndFutureLibrariesNeverReplaceTheCurrentLocation() async throws {
        for payload in [Data("broken".utf8), Data(#"{"schemaVersion":99,"items":[]}"#.utf8)] {
            let root = FileManager.default.temporaryDirectory.appending(path: "library-invalid-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let folder = root.appending(path: "target")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appending(path: "recent-projects.json")
            try payload.write(to: target)
            let source = root.appending(path: "source.json")
            let library = ProjectLibrary(storageURL: source)
            _ = try await library.record(project: ProjectTemplate.commandLineTool.project(named: "Keep"), lastBuild: nil)
            let bookmark = UserDefaults.standard.data(forKey: ProjectLibraryLocation.bookmarkDefaultsKey)
            do { _ = try await library.adoptFolder(folder); XCTFail("must reject invalid library") }
            catch { }
            XCTAssertEqual(try Data(contentsOf: target), payload)
            XCTAssertEqual(UserDefaults.standard.data(forKey: ProjectLibraryLocation.bookmarkDefaultsKey), bookmark)
            let remaining = try await library.items()
            XCTAssertEqual(remaining.map(\.project.name), ["Keep"])
        }
    }

    func testReturningOnDeviceOpensItsExistingLibraryWithoutReplacingIt() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "library-local-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let localURL = root.appending(path: "local.json")
        let local = ProjectLibrary(storageURL: localURL)
        _ = try await local.record(project: ProjectTemplate.commandLineTool.project(named: "Local"), lastBuild: nil)
        let before = try Data(contentsOf: localURL)
        let cloud = ProjectLibrary(storageURL: root.appending(path: "cloud.json"), deviceStorageURL: localURL)
        _ = try await cloud.record(project: ProjectTemplate.commandLineTool.project(named: "Cloud"), lastBuild: nil)
        let opened = try await cloud.useOnDeviceLibrary()
        XCTAssertEqual(opened.map(\.project.name), ["Local"])
        XCTAssertEqual(try Data(contentsOf: localURL), before)
    }

}
