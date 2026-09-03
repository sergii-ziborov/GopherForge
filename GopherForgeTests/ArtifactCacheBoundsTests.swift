import XCTest
import WasmKit
@testable import GopherForge

/// The build cache has to have a ceiling.
///
/// Every edit that reaches a build produces a new key, and editing and running
/// is the ordinary way to use this app — so a map with no eviction grew a
/// parsed WebAssembly module per keystroke-run and never released one.
final class ArtifactCacheBoundsTests: XCTestCase {
    /// The smallest thing `parseWasm` accepts: the magic number and version.
    private let emptyModule: [UInt8] = [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

    func testParsedModulesStopGrowing() throws {
        let cache = GoArtifactCache(toolchainTag: "bounds-test")
        defer { cache.clear() }
        let module = try parseWasm(bytes: emptyModule)

        for index in 0..<64 {
            cache.store(programData: Data(emptyModule), module: module, for: "key-\(index)")
        }

        XCTAssertLessThanOrEqual(
            cache.heldModuleCount, 8,
            "unique builds should evict older ones rather than accumulate"
        )
    }

    /// Eviction is only correct if what survives is what you just used.
    func testTheMostRecentBuildSurvivesEviction() throws {
        let cache = GoArtifactCache(toolchainTag: "bounds-test-recent")
        defer { cache.clear() }
        let module = try parseWasm(bytes: emptyModule)

        for index in 0..<64 {
            cache.store(programData: Data(emptyModule), module: module, for: "key-\(index)")
        }

        XCTAssertNotNil(
            cache.module(for: "key-63"),
            "the build just made is the one most likely to be run again"
        )
    }

    func testVerdictsStopGrowingToo() {
        let cache = GoArtifactCache(toolchainTag: "bounds-test-verdicts")
        defer { cache.clear() }

        for index in 0..<2048 {
            cache.rememberAcceptedBuild(for: "verdict-\(index)")
        }

        XCTAssertTrue(cache.hasAcceptedBuild(for: "verdict-2047"))
        XCTAssertFalse(
            cache.hasAcceptedBuild(for: "verdict-0"),
            "the oldest verdicts should be forgotten rather than kept forever"
        )
    }
}
