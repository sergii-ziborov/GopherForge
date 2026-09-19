import XCTest
import WasmKit
@testable import GopherForge

final class GoArtifactCacheTests: XCTestCase {
    private let emptyModule: [UInt8] = [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

    private func cache() -> GoArtifactCache {
        GoArtifactCache(toolchainTag: "artifact-\(UUID().uuidString)")
    }

    func testTheKeyChangesWhenTheSourceChanges() {
        let cache = cache()
        defer { cache.clear() }
        let first = cache.key(phase: .run, files: ["main.go": "package main\n"])
        let second = cache.key(phase: .run, files: ["main.go": "package main\nfunc main() {}\n"])
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.count, 64)
    }

    func testTheKeyChangesWhenThePhaseChanges() {
        let cache = cache()
        let files = ["main.go": "package main\n"]
        XCTAssertNotEqual(
            cache.key(phase: .build, files: files),
            cache.key(phase: .run, files: files)
        )
    }

    func testTheKeyChangesWhenThePackagePatternChanges() {
        let cache = cache()
        let files = ["main.go": "package main\n"]
        XCTAssertNotEqual(
            cache.key(phase: .run, files: files, packagePattern: "./cmd/one"),
            cache.key(phase: .run, files: files, packagePattern: "./cmd/two")
        )
    }

    func testAMissIsNilRatherThanACrash() {
        let cache = cache()
        defer { cache.clear() }
        XCTAssertNil(cache.module(for: String(repeating: "0", count: 64)))
        XCTAssertFalse(cache.hasAcceptedBuild(for: "never"))
        XCTAssertEqual(cache.storedByteCount, 0)
        XCTAssertEqual(cache.heldModuleCount, 0)
    }

    func testAStoredModuleCanBeReadBack() throws {
        let cache = cache()
        defer { cache.clear() }
        let module = try parseWasm(bytes: emptyModule)
        let key = cache.key(phase: .run, files: ["main.go": "a"])
        cache.store(programData: Data(emptyModule), module: module, for: key)

        XCTAssertNotNil(cache.module(for: key))
        XCTAssertGreaterThan(cache.storedByteCount, 0)
        XCTAssertEqual(cache.heldModuleCount, 1)
    }

    func testClearDropsVerdictsAndBytes() throws {
        let cache = cache()
        let module = try parseWasm(bytes: emptyModule)
        let key = "remembered"
        cache.rememberAcceptedBuild(for: key)
        cache.store(programData: Data(emptyModule), module: module, for: key)
        XCTAssertTrue(cache.hasAcceptedBuild(for: key))

        cache.clear()
        XCTAssertFalse(cache.hasAcceptedBuild(for: key))
        XCTAssertNil(cache.module(for: key))
        XCTAssertEqual(cache.heldModuleCount, 0)
    }

    func testReRememberingAVerdictDoesNotResetEvictionOrder() {
        let cache = cache()
        defer { cache.clear() }
        cache.rememberAcceptedBuild(for: "once")
        cache.rememberAcceptedBuild(for: "once")
        XCTAssertTrue(cache.hasAcceptedBuild(for: "once"))
    }

    func testCachesWithDifferentTagsDoNotShareArtifacts() throws {
        let left = GoArtifactCache(toolchainTag: "left-\(UUID().uuidString)")
        let right = GoArtifactCache(toolchainTag: "right-\(UUID().uuidString)")
        defer {
            left.clear()
            right.clear()
        }
        let module = try parseWasm(bytes: emptyModule)
        let key = left.key(phase: .run, files: ["main.go": "shared-looking"])
        left.store(programData: Data(emptyModule), module: module, for: key)
        XCTAssertNil(right.module(for: key))
    }
}
