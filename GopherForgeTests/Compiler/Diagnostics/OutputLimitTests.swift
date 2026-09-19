import XCTest
@testable import GopherForge

/// A guest's output has to be bounded while it runs, not after.
///
/// Nothing else bounds it. The memory limiter never fires on printing, because
/// the bytes leave the sandbox as fast as they are produced, so
/// `for { fmt.Println("x") }` used to fill the device's storage and then hand
/// the app a string too large to render. Reading only the first N bytes
/// afterwards would not have helped: a program like that has no afterwards.
final class OutputLimitTests: XCTestCase {
    private func write(_ byteCount: Int, to stream: BoundedStream) throws {
        let handle = FileHandle(fileDescriptor: stream.writingDescriptor, closeOnDealloc: false)
        let chunk = Data(repeating: UInt8(ascii: "x"), count: 4096)
        var written = 0
        while written < byteCount {
            try handle.write(contentsOf: chunk.prefix(min(4096, byteCount - written)))
            written += 4096
        }
    }

    func testOutputPastTheLimitIsDroppedRatherThanKept() throws {
        let limit = 8 * 1024
        let stream = BoundedStream(limitBytes: limit)
        try write(limit * 20, to: stream)

        let text = stream.take()
        // What is kept is the limit; the rest is a short sentence, not 160 KiB.
        XCTAssertLessThan(
            text.utf8.count, limit + 512,
            "a program that prints without stopping should not be kept in full"
        )
    }

    func testTheRunSaysWhatItDropped() throws {
        let stream = BoundedStream(limitBytes: 4096)
        try write(64 * 1024, to: stream)

        let text = stream.take()
        XCTAssertTrue(
            text.contains("discarded"),
            "silently truncated output reads as a program that stopped printing"
        )
    }

    /// The ordinary case has to be untouched: no truncation, no notice.
    func testOutputUnderTheLimitIsKeptWhole() throws {
        let stream = BoundedStream(limitBytes: 64 * 1024)
        let handle = FileHandle(fileDescriptor: stream.writingDescriptor, closeOnDealloc: false)
        try handle.write(contentsOf: Data("1\n4\n9\n16\n25\n".utf8))

        XCTAssertEqual(stream.take(), "1\n4\n9\n16\n25\n")
    }

    /// The ceilings themselves: a person's program and the toolchain are not
    /// the same case, and collapsing them would either truncate a real build's
    /// diagnostics or let a runaway program keep 16 MiB.
    func testTheToolchainIsAllowedMoreThanAUserProgram() {
        XCTAssertGreaterThan(
            WasmSandboxPolicy.toolchainOutputLimitBytes,
            WasmSandboxPolicy.userProgramOutputLimitBytes
        )
    }
}
