import XCTest
@testable import GopherForge

final class GoRuntimeFailureReaderTests: XCTestCase {
    func testADeadlockIsTeachable() {
        let stderr = "fatal error: all goroutines are asleep - deadlock!"
        XCTAssertEqual(
            GoRuntimeFailureReader.describe(stderr: stderr),
            "Every goroutine is blocked, so the program can never make progress."
        )
        let diagnostic = try? XCTUnwrap(GoRuntimeFailureReader.diagnostics(stderr: stderr).first)
        XCTAssertEqual(diagnostic?.conceptTag, GoConcept.deadlock)
        XCTAssertEqual(diagnostic?.rendered, stderr)
    }

    func testSendOnClosedChannel() {
        let stderr = "panic: send on closed channel"
        XCTAssertTrue(GoRuntimeFailureReader.describe(stderr: stderr)?.contains("closed") == true)
        XCTAssertEqual(
            GoRuntimeFailureReader.diagnostics(stderr: stderr).first?.conceptTag,
            GoConcept.channelClose
        )
    }

    func testCloseOfClosedChannel() {
        XCTAssertNotNil(
            GoRuntimeFailureReader.describe(stderr: "panic: close of closed channel")
        )
    }

    func testANilMapWrite() {
        let stderr = "panic: assignment to entry in nil map"
        XCTAssertTrue(GoRuntimeFailureReader.describe(stderr: stderr)?.contains("map") == true)
        XCTAssertEqual(
            GoRuntimeFailureReader.diagnostics(stderr: stderr).first?.conceptTag,
            GoConcept.mapZeroValue
        )
    }

    func testIndexOutOfRange() {
        XCTAssertTrue(
            GoRuntimeFailureReader.describe(stderr: "panic: runtime error: index out of range [3] with length 1")?
                .contains("slice") == true
        )
    }

    func testANilPointer() {
        XCTAssertTrue(
            GoRuntimeFailureReader.describe(
                stderr: "panic: runtime error: invalid memory address or nil pointer dereference"
            )?.contains("nil") == true
        )
    }

    func testUnknownStderrProducesNothing() {
        XCTAssertNil(GoRuntimeFailureReader.describe(stderr: "hello from the program"))
        XCTAssertTrue(GoRuntimeFailureReader.diagnostics(stderr: "hello from the program").isEmpty)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertNotNil(
            GoRuntimeFailureReader.describe(stderr: "ALL GOROUTINES ARE ASLEEP - DEADLOCK!")
        )
    }

    func testTheFirstPanicLineIsWhatGetsRendered() {
        let stderr = """
        some noise
        panic: send on closed channel
        goroutine 1 [running]:
        """
        XCTAssertEqual(
            GoRuntimeFailureReader.diagnostics(stderr: stderr).first?.rendered,
            "panic: send on closed channel"
        )
    }

    func testAFatalErrorLineIsPreferredOverTheSummary() {
        let stderr = "fatal error: all goroutines are asleep - deadlock!"
        XCTAssertEqual(
            GoRuntimeFailureReader.diagnostics(stderr: stderr).first?.rendered,
            stderr
        )
    }
}
