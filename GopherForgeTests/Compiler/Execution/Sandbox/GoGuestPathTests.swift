import XCTest
@testable import GopherForge

final class GoGuestPathLayoutTests: XCTestCase {
    func testArchiveAndProgramPathsStayUnderTempAndWork() {
        XCTAssertTrue(GoGuestPath.archive(for: "example.com/a/b").hasPrefix("/tmp/"))
        XCTAssertTrue(GoGuestPath.program(for: "example.com/a", suffix: ".test").hasPrefix("/work/"))
        XCTAssertEqual(GoGuestPath.runProgram, "/work/program.wasm")
        XCTAssertTrue(GoGuestPath.importConfiguration(for: "p").hasPrefix("/tmp/"))
        XCTAssertTrue(GoGuestPath.generatedTestMain(for: "p").hasSuffix("_testmain.go"))
        XCTAssertTrue(
            GoGuestPath.standardLibraryArchive(for: "fmt")
                .hasPrefix(GoGuestPath.standardLibraryPackages)
        )
        XCTAssertTrue(GoGuestPath.vetConfiguration(for: "p").hasSuffix(".vet.cfg"))
        XCTAssertTrue(GoGuestPath.vetFacts(for: "p").hasSuffix(".vetx"))
    }

    func testSourceJoinsTheWorkRoot() {
        XCTAssertEqual(GoGuestPath.source("cmd/one/main.go"), "/work/cmd/one/main.go")
    }

    func testFlatteningIsInjectiveForUnderscoreAndSlash() {
        XCTAssertNotEqual(
            GoGuestPath.flattened("forge/test"),
            GoGuestPath.flattened("forge_test")
        )
        XCTAssertNotEqual(
            GoGuestPath.flattened("example.com/a-b"),
            GoGuestPath.flattened("example.com/a_b")
        )
    }
}
