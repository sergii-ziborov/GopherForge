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

    /// The step cache trimmed on entry count alone, which is not a ceiling on
    /// storage: a package archive runs from a few kilobytes to several
    /// megabytes, so four hundred of them can mean almost any size.
    func testTheStepCacheIsBoundedInBytesAndNotOnlyInCount() {
        // A small budget on purpose: with the shipped 192 MiB the test would
        // have to write 192 MiB to reach it, and one that writes less than the
        // budget asserts nothing.
        let budget = 4 * 1024 * 1024
        let cache = GoStepArtifactCache(
            toolchainTag: "bounds-test-steps",
            maximumBytes: budget
        )
        defer { cache.clear() }

        // Keys are validated as 64 hex characters, so they are built that way.
        // Well under the 400-entry ceiling, so bytes are the only thing that
        // can trim this.
        let archive = Data(repeating: 0x41, count: 512 * 1024)
        for index in 0..<32 {
            cache.store(archive, for: String(format: "%064x", index))
        }

        XCTAssertLessThanOrEqual(
            cache.storedByteCount, Int64(budget),
            "the step cache should trim on bytes as well as on entry count"
        )
        XCTAssertGreaterThan(
            cache.storedByteCount, 0,
            "trimming should not empty the cache it is bounding"
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
