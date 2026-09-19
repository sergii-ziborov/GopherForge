import XCTest
@testable import GopherForge

final class GoStepArtifactCacheTests: XCTestCase {
    private func cache() -> GoStepArtifactCache {
        GoStepArtifactCache(toolchainTag: "steps-\(UUID().uuidString)")
    }

    private func hex(_ value: Int) -> String {
        String(format: "%064x", value)
    }

    func testAValidKeyRoundTrips() {
        let cache = cache()
        defer { cache.clear() }
        let key = hex(1)
        let payload = Data("archive".utf8)
        cache.store(payload, for: key)
        XCTAssertEqual(cache.archive(for: key), payload)
        XCTAssertGreaterThan(cache.storedByteCount, 0)
    }

    func testAnInvalidKeyIsNeverStored() {
        let cache = cache()
        defer { cache.clear() }
        cache.store(Data("nope".utf8), for: "not-hex")
        cache.store(Data("nope".utf8), for: String(repeating: "g", count: 64))
        cache.store(Data("nope".utf8), for: String(repeating: "a", count: 63))
        XCTAssertNil(cache.archive(for: "not-hex"))
        XCTAssertEqual(cache.storedByteCount, 0)
    }

    func testAMissIsNil() {
        let cache = cache()
        defer { cache.clear() }
        XCTAssertNil(cache.archive(for: hex(99)))
    }

    func testClearRemovesTheBytes() {
        let cache = cache()
        cache.store(Data("x".utf8), for: hex(2))
        cache.clear()
        XCTAssertNil(cache.archive(for: hex(2)))
        XCTAssertEqual(cache.storedByteCount, 0)
    }

    func testOverwritingAKeyReplacesTheBytes() {
        let cache = cache()
        defer { cache.clear() }
        let key = hex(3)
        cache.store(Data("old".utf8), for: key)
        cache.store(Data("new-bytes".utf8), for: key)
        XCTAssertEqual(cache.archive(for: key), Data("new-bytes".utf8))
    }

    func testAByteBudgetDropsTheOldest() {
        let cache = GoStepArtifactCache(
            toolchainTag: "steps-budget-\(UUID().uuidString)",
            maximumBytes: 2_000
        )
        defer { cache.clear() }
        cache.store(Data(repeating: 1, count: 1_200), for: hex(1))
        cache.store(Data(repeating: 2, count: 1_200), for: hex(2))
        XCTAssertLessThanOrEqual(cache.storedByteCount, 2_000)
        XCTAssertNotNil(cache.archive(for: hex(2)), "the newest archive should survive")
    }
}
