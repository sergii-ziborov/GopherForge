import XCTest
@testable import GopherForge

final class GzipStreamTests: XCTestCase {
    func testARoundTripPreservesBytes() throws {
        let original = Data("hello from gopherforge\n".utf8)
        let compressed = try GzipStream.compress(original)
        XCTAssertEqual(compressed.prefix(2), Data([0x1f, 0x8b]))
        let restored = try GzipStream.decompress(compressed, limit: 1_000)
        XCTAssertEqual(restored, original)
    }

    func testANonGzipBlobIsRefused() {
        XCTAssertThrowsError(try GzipStream.decompress(Data("not gzip".utf8), limit: 100)) { error in
            XCTAssertEqual(error as? GzipStream.GzipError, .notGzip)
        }
    }

    func testFlagsOnTheHeaderAreCorruptRatherThanGuessed() throws {
        var data = try GzipStream.compress(Data("x".utf8))
        data[3] = 0x08
        XCTAssertThrowsError(try GzipStream.decompress(data, limit: 100)) { error in
            XCTAssertEqual(error as? GzipStream.GzipError, .corrupt)
        }
    }

    func testAOneBytePayloadRoundTrips() throws {
        let compressed = try GzipStream.compress(Data([0x7a]))
        XCTAssertEqual(try GzipStream.decompress(compressed, limit: 10), Data([0x7a]))
    }
}
