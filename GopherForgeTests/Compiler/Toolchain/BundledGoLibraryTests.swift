import Foundation
import XCTest
@testable import GopherForge

final class BundledGoLibraryTests: XCTestCase {
    func testCorruptArchiveIsRejectedWithoutInstallingAnything() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = directory.appendingPathComponent("goroot.zip")
        try Data("not the signed archive".utf8).write(to: archive)
        let destination = directory.appendingPathComponent("installed")
        XCTAssertThrowsError(try BundledGoLibrary.prepare(
            archive: archive, checksum: String(repeating: "0", count: 64), destination: destination
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testBundledLibraryCanBeRestoredAfterCacheEviction() throws {
        let layout = try XCTUnwrap(GoToolchainLocator().resolve(prepareLibrary: false))
        let archive = layout.root.appendingPathComponent("goroot.zip")
        let checksum = try String(contentsOf: layout.root.appendingPathComponent("goroot.sha256"), encoding: .utf8)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        try BundledGoLibrary.prepare(archive: archive, checksum: checksum, destination: destination)
        let runtime = destination.appendingPathComponent("goroot/pkg/wasip1_wasm/runtime.a")
        let original = try Data(contentsOf: runtime)
        XCTAssertFalse(original.isEmpty)
        try FileManager.default.removeItem(at: destination)
        try BundledGoLibrary.prepare(archive: archive, checksum: checksum, destination: destination)
        XCTAssertEqual(try Data(contentsOf: runtime), original)
    }
}
