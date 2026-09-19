import XCTest
@testable import GopherForge

final class GoToolInvocationTests: XCTestCase {
    func testTheGuestIsWasip1Wasm() {
        let environment = GoToolInvocation.environment(goVersion: "go1.24.3")
        XCTAssertEqual(environment["GOOS"], "wasip1")
        XCTAssertEqual(environment["GOARCH"], "wasm")
        XCTAssertEqual(environment["GOPROXY"], "off")
        XCTAssertEqual(environment["GOTOOLCHAIN"], "local")
        XCTAssertEqual(environment["GOVERSION"], "go1.24.3")
    }

    func testTheSandboxHasNoNetworkAndALocalCache() {
        let environment = GoToolInvocation.environment(goVersion: "go1.24")
        XCTAssertEqual(environment["GOROOT"], GoGuestPath.goroot)
        XCTAssertEqual(environment["GOCACHE"], GoGuestPath.cache)
        XCTAssertEqual(environment["GOTMPDIR"], GoGuestPath.temp)
        XCTAssertTrue(environment["GOMODCACHE"]?.hasPrefix(GoGuestPath.cache) == true)
        XCTAssertEqual(environment["HOME"], GoGuestPath.work)
    }

    func testProgramArgumentsStartWithTheProgramName() {
        XCTAssertEqual(GoToolInvocation.programArguments(), ["program"])
        XCTAssertEqual(GoToolInvocation.programArguments(programName: "testmain"), ["testmain"])
    }
}
