import XCTest
@testable import GopherForge

final class WasmSandboxPolicyTests: XCTestCase {
    func testUserProgramsGetOneWritableDirectory() {
        XCTAssertEqual(WasmSandboxPolicy.writableGuestDirectory, "/sandbox")
    }

    func testToolchainIsAllowedMoreMemoryThanUserPrograms() {
        XCTAssertGreaterThan(
            WasmSandboxPolicy.toolchainMemoryLimitBytes,
            WasmSandboxPolicy.userProgramMemoryLimitBytes
        )
    }

    func testGrowthWithinTheLimitIsAllowed() throws {
        let limiter = WasmSandboxResourceLimiter()
        XCTAssertTrue(try limiter.limitMemoryGrowth(to: 1 << 20))
        XCTAssertNil(limiter.deniedResource)
    }

    func testGrowthPastTheLimitIsDeniedAndRemembered() throws {
        let limiter = WasmSandboxResourceLimiter()
        XCTAssertFalse(
            try limiter.limitMemoryGrowth(to: WasmSandboxPolicy.userProgramMemoryLimitBytes + 1)
        )
        XCTAssertEqual(limiter.deniedResource, .memory)
    }

    func testTableGrowthPastTheLimitIsDenied() throws {
        let limiter = WasmSandboxResourceLimiter()
        XCTAssertFalse(
            try limiter.limitTableGrowth(to: WasmSandboxPolicy.userProgramTableElementLimit + 1)
        )
        XCTAssertEqual(limiter.deniedResource, .table)
    }
}
