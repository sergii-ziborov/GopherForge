import XCTest
@testable import GopherForge

final class ZipArchiveTests: XCTestCase {
    func testADeflatedRoundTripKeepsBytesAndNames() throws {
        let files: [String: Data] = [
            "github.com/x/y@v1.0.0/go.mod": Data("module github.com/x/y\n".utf8),
            "github.com/x/y@v1.0.0/y.go": Data("package y\nfunc F() {}\n".utf8),
            "github.com/x/y@v1.0.0/LICENSE": Data("MIT\n".utf8),
        ]
        let zip = try ZipArchive.data(from: files)
        let restored = try ZipArchive.files(from: zip, limit: 1_000_000)
        XCTAssertEqual(restored, files)
        XCTAssertEqual(zip.prefix(2), Data([0x50, 0x4b]))
    }

    func testStoreAndAnEmptyFileAreReadable() throws {
        let files = ["empty.txt": Data(), "plain.txt": Data("hi".utf8)]
        let zip = try ZipArchive.data(from: files, compress: false)
        XCTAssertEqual(try ZipArchive.files(from: zip, limit: 100), files)
    }

    func testATraversalIsRefusedOnUnzip() throws {
        XCTAssertNil(ZipArchive.resolve("../etc/passwd", under: FileManager.default.temporaryDirectory))
        XCTAssertNil(ZipArchive.resolve("/absolute", under: FileManager.default.temporaryDirectory))
    }

    func testACeilingStopsBeforeTheWholeArchiveIsHeld() throws {
        let zip = try ZipArchive.data(from: ["a.bin": Data(repeating: 1, count: 200)])
        XCTAssertThrowsError(try ZipArchive.files(from: zip, limit: 50)) { error in
            guard case .some(.tooLarge) = error as? ZipArchive.ZipError else {
                return XCTFail("\(error)")
            }
        }
    }

    func testGarbageIsUnreadable() {
        XCTAssertThrowsError(try ZipArchive.files(from: Data("not a zip".utf8), limit: 100)) { error in
            XCTAssertEqual(error as? ZipArchive.ZipError, .unreadable)
        }
    }

    func testAModuleZipFeedsTheSameHashGoWould() throws {
        let files: [String: Data] = [
            "example.com/tiny@v1.0.0/go.mod": Data("module example.com/tiny\n\ngo 1.24\n".utf8),
            "example.com/tiny@v1.0.0/tiny.go": Data("package tiny\n\nfunc Answer() int { return 42 }\n".utf8),
            "example.com/tiny@v1.0.0/LICENSE": Data("MIT\n".utf8),
        ]
        let zip = try ZipArchive.data(from: files)
        let archive = try GoModuleArchive(
            data: zip,
            reference: GoModuleReference.validated(path: "example.com/tiny", version: "v1.0.0")!
        )
        XCTAssertEqual(try archive.hash(), "h1:MX1+3ZScKiNvQRVULT5GnBvjTTIGcxG6nTHMuJiKe2c=")
        XCTAssertEqual(archive.vendoredFiles()["tiny.go"], "package tiny\n\nfunc Answer() int { return 42 }\n")
    }

    func testTheBundledLibraryZipIsReadableWhenStaged() throws {
        let root = try TestRepoRoot.url()
            .appending(path: "build/Resources/Toolchain")
        guard let zip = Self.firstGoroot(under: root) else {
            throw XCTSkip("toolchain is not staged in this checkout")
        }
        let data = try Data(contentsOf: zip, options: [.mappedIfSafe])
        let entries = try ZipArchive.catalog(in: data)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertTrue(entries.contains { $0.path.hasSuffix("runtime.a") })
        XCTAssertTrue(entries.allSatisfy { $0.method == ZipArchive.deflate })
        let license = try XCTUnwrap(entries.first { $0.path.hasSuffix("LICENSE") })
        let text = try ZipArchive.extract(license, from: data, remaining: license.uncompressedSize)
        XCTAssertTrue(String(decoding: text, as: UTF8.self).contains("Go Authors"))
        let version = try XCTUnwrap(entries.first { $0.path.hasSuffix("VERSION") })
        XCTAssertEqual(
            String(decoding: try ZipArchive.extract(version, from: data, remaining: 64), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "go1.27.1"
        )
    }

    private static func firstGoroot(under root: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == "goroot.zip" { return url }
        }
        return nil
    }
}
