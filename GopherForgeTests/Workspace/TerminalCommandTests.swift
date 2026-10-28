import XCTest
@testable import GopherForge

final class TerminalCommandTests: XCTestCase {
    func testGoVerbsMapToPhases() {
        XCTAssertEqual(TerminalCommand.parse("go build"), .build)
        XCTAssertEqual(TerminalCommand.parse("go run"), .run)
        XCTAssertEqual(TerminalCommand.parse("go test"), .test)
        XCTAssertEqual(TerminalCommand.parse("go vet"), .vet)
        XCTAssertEqual(TerminalCommand.parse("go fmt"), .format)
        XCTAssertEqual(TerminalCommand.parse("gofmt"), .format)
        XCTAssertEqual(TerminalCommand.parse("go mod"), .modules)
        XCTAssertEqual(TerminalCommand.parse("  go   build  ").phase, .build)
    }

    func testProjectInspectionCommands() {
        XCTAssertEqual(TerminalCommand.parse("ls"), .list(nil))
        XCTAssertEqual(TerminalCommand.parse("ls greet"), .list("greet"))
        XCTAssertEqual(TerminalCommand.parse("cat main.go"), .show("main.go"))
        XCTAssertEqual(TerminalCommand.parse("cat"), .unknown("cat needs a file"))
        XCTAssertEqual(TerminalCommand.parse("pwd"), .printWorkingDirectory)
        XCTAssertEqual(TerminalCommand.parse("clear"), .clear)
        XCTAssertEqual(TerminalCommand.parse("help"), .help)
    }

    func testUnknownInputIsNotForwarded() {
        XCTAssertEqual(TerminalCommand.parse(""), .unknown(""))
        XCTAssertEqual(TerminalCommand.parse("rm -rf /"), .unknown("rm -rf /"))
        XCTAssertNil(TerminalCommand.parse("ls").phase)
        XCTAssertTrue(TerminalCommand.helpText.contains("go build"))
        XCTAssertTrue(TerminalCommand.helpText.contains("not a shell"))
    }
    func testUnsupportedArgumentsNeverDegradeToAnOrdinaryPhase() {
        for command in ["go test -race", "go test -run TestPass", "go test -bench .", "go run ./cmd/foo arg1", "go build ./cmd/foo", "go mod tidy", "gofmt -w main.go", "go test --unknown", "go run --", "go run ''", "go test\ngo run", "pwd extra", "ls a b", "cat a.go b.go"] {
            let parsed = TerminalCommand.parse(command)
            guard case .unsupported = parsed else { return XCTFail("must reject: \(command)") }
            XCTAssertNil(parsed.phase, command)
        }
        XCTAssertEqual(TerminalCommand.parse("go\ttest"), .test)
    }

}
