import XCTest
@testable import GopherForge

final class GoProgramArtifactsTests: XCTestCase {
    func testAnEmptySandboxProducesNothing() throws {
        let sandbox = FileManager.default.temporaryDirectory
            .appending(path: "artifacts-empty-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        XCTAssertTrue(GoProgramArtifacts.collect(from: sandbox).isEmpty)
    }

    func testAMissingSandboxIsEmptyRatherThanACrash() {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "artifacts-missing-\(UUID().uuidString)")
        XCTAssertTrue(GoProgramArtifacts.collect(from: missing).isEmpty)
    }

    func testRecognisedImagesAreCollectedNewestLastByName() throws {
        let sandbox = FileManager.default.temporaryDirectory
            .appending(path: "artifacts-ok-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        try Data("png-a".utf8).write(to: sandbox.appending(path: "b.png"))
        try Data("png-b".utf8).write(to: sandbox.appending(path: "a.PNG"))
        try Data("txt".utf8).write(to: sandbox.appending(path: "notes.txt"))

        let collected = GoProgramArtifacts.collect(from: sandbox)
        XCTAssertEqual(collected.images.map(\.name), ["a.PNG", "b.png"])
        XCTAssertEqual(collected.images.first?.data, Data("png-b".utf8))
    }

    func testAnOversizedImageIsDropped() throws {
        let sandbox = FileManager.default.temporaryDirectory
            .appending(path: "artifacts-big-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let huge = Data(repeating: 0x41, count: GoProgramArtifacts.maximumImageBytes + 1)
        try huge.write(to: sandbox.appending(path: "huge.png"))
        try Data("ok".utf8).write(to: sandbox.appending(path: "ok.jpg"))

        let collected = GoProgramArtifacts.collect(from: sandbox)
        XCTAssertEqual(collected.images.map(\.name), ["ok.jpg"])
    }

    func testTheImageCapStopsARunawayProgram() throws {
        let sandbox = FileManager.default.temporaryDirectory
            .appending(path: "artifacts-cap-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        for index in 0..<(GoProgramArtifacts.maximumImages + 3) {
            try Data("\(index)".utf8).write(
                to: sandbox.appending(path: String(format: "%02d.gif", index))
            )
        }

        XCTAssertEqual(
            GoProgramArtifacts.collect(from: sandbox).images.count,
            GoProgramArtifacts.maximumImages
        )
    }

    func testJpegAndGifAreRecognised() throws {
        let sandbox = FileManager.default.temporaryDirectory
            .appending(path: "artifacts-ext-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        try Data("j".utf8).write(to: sandbox.appending(path: "shot.jpeg"))
        try Data("g".utf8).write(to: sandbox.appending(path: "anim.gif"))

        XCTAssertEqual(
            Set(GoProgramArtifacts.collect(from: sandbox).images.map(\.name)),
            ["shot.jpeg", "anim.gif"]
        )
    }
}
