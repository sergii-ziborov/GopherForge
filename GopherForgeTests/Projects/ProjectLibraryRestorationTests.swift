import XCTest
@testable import GopherForge

final class ProjectLibraryRestorationTests: XCTestCase {
    func testUnreadableChosenBookmarkDoesNotFallBackToOnDeviceLibrary() async throws {
        let key = ProjectLibraryLocation.bookmarkDefaultsKey
        let before = UserDefaults.standard.data(forKey: key)
        defer {
            if let before { UserDefaults.standard.set(before, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set(Data("invalid bookmark".utf8), forKey: key)
        XCTAssertThrowsError(try ProjectLibraryLocation.restoredFileURL())
        let library = ProjectLibrary()
        do { _ = try await library.items(); XCTFail("must not substitute the local library") }
        catch { XCTAssertEqual(error as? ProjectLibrary.StorageError, .bookmarkUnavailable) }
        XCTAssertEqual(UserDefaults.standard.data(forKey: key), Data("invalid bookmark".utf8))
    }

    func testDeletedKnownDocumentIsStillMissingAfterActorRestartWhenBackupExists() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "restore-known-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "projects.json")
        let library = ProjectLibrary(storageURL: url)
        _ = try await library.record(project: ProjectTemplate.commandLineTool.project(named: "Kept"), lastBuild: nil)
        XCTAssertTrue(ProjectLibraryDocument.hasRecoveryFiles(beside: url))
        try FileManager.default.removeItem(at: url)
        do { _ = try await ProjectLibrary(storageURL: url).items(); XCTFail("must not return an empty library") }
        catch { XCTAssertEqual(error as? ProjectLibrary.StorageError, .missingDocument) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testVersionMergeIsStableAndCannotLoseSourceOnAConstructedUUIDCollision() {
        func item(_ id: UUID, _ source: String) -> ProjectLibraryItem {
            ProjectLibraryItem(id: id, project: GopherForgeProject(name: "Source", files: ["main.go": source], entryFile: "main.go", provenance: nil), lastOpenedAt: Date(timeIntervalSince1970: 1_000), sourceRevision: 1)
        }
        let id = UUID(), old = item(id, "remote source")
        let wouldCollide = ProjectLibraryDocument.recoveryCopy(old, reason: "iCloud recovery", stable: true)
        var state = ProjectLibraryDocument.State(items: [item(id, "current source"), item(wouldCollide.id, "independent source")])
        let remote = ProjectLibraryDocument.State(items: [old])
        ProjectLibraryDocument.merge(remote, into: &state)
        XCTAssertEqual(Set(state.items.compactMap { $0.project.files["main.go"] }), ["remote source", "current source", "independent source"])
        let identities = state.items.map(\.id)
        ProjectLibraryDocument.merge(remote, into: &state)
        XCTAssertEqual(state.items.map(\.id), identities, "repeated reads must not manufacture duplicate recovery projects")
    }
}
