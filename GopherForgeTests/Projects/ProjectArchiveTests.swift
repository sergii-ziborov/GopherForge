import XCTest
@testable import GopherForge

/// Packing a project and getting it back.
///
/// A tar.gz is only worth writing by hand if it is really a tar.gz, so these
/// check the format rather than only the round trip: gzip's magic bytes and
/// its CRC, and tar's own header fields.
final class ProjectArchiveTests: XCTestCase {
    private let project: [String: String] = [
        "go.mod": "module playground\n\ngo 1.24\n",
        "main.go": "package main\n\nfunc main() {}\n",
        "internal/greet/greet.go": "package greet\n\nfunc Say() string { return \"hi\" }\n",
    ]

    func testAProjectSurvivesTheRoundTrip() throws {
        let packed = try ProjectArchive.gzip(ProjectArchive.tar(files: project, root: "playground"))
        let unpacked = try ProjectArchive.files(fromTar: ProjectArchive.gunzip(packed))

        XCTAssertEqual(unpacked, project)
    }

    func testTheArchiveIsRealGzip() throws {
        let packed = try ProjectArchive.gzip(ProjectArchive.tar(files: project, root: "playground"))

        XCTAssertEqual(Array(packed.prefix(3)), [0x1f, 0x8b, 0x08], "gzip magic and deflate")
        XCTAssertGreaterThan(packed.count, 18, "header and trailer alone are 18 bytes")
    }

    /// A tar is a 512-byte header per file and nothing else. If the size field
    /// is wrong, every reader but this one gets the wrong bytes.
    func testTarHeadersAreWellFormed() throws {
        let tar = try ProjectArchive.tar(files: ["a.go": "package a\n"], root: "proj")

        XCTAssertEqual(tar.count % 512, 0, "a tar is a whole number of blocks")
        let name = String(decoding: tar.prefix(9), as: UTF8.self)
        XCTAssertEqual(name, "proj/a.go")
        let size = String(decoding: tar.subdata(in: 124..<135), as: UTF8.self)
        XCTAssertEqual(Int(size, radix: 8), 10, "octal size of \"package a\\n\"")
        XCTAssertEqual(tar[156], UInt8(ascii: "0"), "a regular file")
        XCTAssertEqual(
            String(decoding: tar.subdata(in: 257..<262), as: UTF8.self), "ustar"
        )
    }

    /// Exporting the same project twice should produce the same bytes, or two
    /// exports cannot be compared and every one looks like a change.
    func testExportingTwiceProducesIdenticalBytes() throws {
        let first = try ProjectArchive.gzip(ProjectArchive.tar(files: project, root: "p"))
        let second = try ProjectArchive.gzip(ProjectArchive.tar(files: project, root: "p"))

        XCTAssertEqual(first, second)
    }

    // MARK: - Refusals

    /// An archive is untrusted input even when this app wrote it.
    func testAnEntryThatWouldEscapeIsRefused() {
        XCTAssertNil(ProjectArchive.projectPath(from: "proj/../../etc/passwd"))
        XCTAssertNil(ProjectArchive.projectPath(from: "/absolute"))
        XCTAssertNil(ProjectArchive.projectPath(from: "single"))
        XCTAssertEqual(ProjectArchive.projectPath(from: "proj/a/b.go"), "a/b.go")
    }

    func testAPathTooLongForTarIsRefusedRatherThanTruncated() {
        let long = String(repeating: "a/", count: 60) + "x.go"
        XCTAssertThrowsError(try ProjectArchive.tar(files: [long: ""], root: "p")) { error in
            guard case .pathTooLong = error as? ProjectArchive.ArchiveError else {
                return XCTFail("expected pathTooLong, got \(error)")
            }
        }
    }

    func testSomethingThatIsNotGzipIsRefused() {
        XCTAssertThrowsError(try ProjectArchive.gunzip(Data("not an archive at all".utf8)))
    }

    /// The CRC is the only thing that notices a corrupted payload, so it has to
    /// actually be checked.
    func testACorruptedArchiveIsRefused() throws {
        var packed = try ProjectArchive.gzip(ProjectArchive.tar(files: project, root: "p"))
        packed[packed.startIndex + 30] ^= 0xFF

        XCTAssertThrowsError(try ProjectArchive.gunzip(packed))
    }

    /// Pinned against the published CRC-32 of "123456789", the standard check
    /// value: an implementation that agrees with it agrees with every other.
    func testCrcMatchesTheStandardCheckValue() {
        XCTAssertEqual(GzipStream.crc32(Data("123456789".utf8)), 0xCBF4_3926)
    }
}
