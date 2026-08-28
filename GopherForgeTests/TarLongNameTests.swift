import XCTest
@testable import GopherForge

/// Paths too long for a tar header.
///
/// A ustar name field is 100 bytes. Anything longer is carried by an extra
/// header before the entry — GNU writes one kind, pax another, and GitHub's
/// tarballs use pax. Without reading them a deep file is silently renamed to
/// its own first 100 bytes, which is worse than dropping it.
final class TarLongNameTests: XCTestCase {
    private let deepPath = "internal/" + String(repeating: "verylongdirectory/", count: 6) + "deep.go"

    private func block(name: String, size: Int, type: UInt8) -> Data {
        var block = [UInt8](repeating: 0, count: 512)
        for (index, byte) in Array(name.utf8).prefix(99).enumerated() { block[index] = byte }
        for (index, byte) in Array(String(format: "%011o", size).utf8).enumerated() {
            block[124 + index] = byte
        }
        block[156] = type
        for index in 148..<156 { block[index] = UInt8(ascii: " ") }
        let checksum = block.reduce(0) { $0 + Int($1) }
        for (index, byte) in Array(String(format: "%06o", checksum).utf8).enumerated() {
            block[148 + index] = byte
        }
        block[154] = 0
        block[155] = UInt8(ascii: " ")
        return Data(block)
    }

    private func padded(_ data: Data) -> Data {
        var out = data
        let remainder = data.count % 512
        if remainder != 0 { out.append(Data(count: 512 - remainder)) }
        return out
    }

    func testAPaxHeaderNamesTheEntryThatFollows() throws {
        let full = "example-main/\(deepPath)"
        let record = "path=\(full)\n"
        // A pax record is "<length> <key>=<value>\n", where the length counts
        // itself — the same way the format defines it.
        var length = record.utf8.count + 2
        length = record.utf8.count + String(length).utf8.count + 1
        let body = Data("\(length) \(record)".utf8)
        let contents = Data("package deep\n".utf8)

        var tar = Data()
        tar.append(block(name: "pax_header", size: body.count, type: UInt8(ascii: "x")))
        tar.append(padded(body))
        tar.append(block(name: "example-main/truncated.go", size: contents.count, type: UInt8(ascii: "0")))
        tar.append(padded(contents))
        tar.append(Data(count: 1024))

        let files = try ProjectArchive.files(fromTar: tar)

        XCTAssertEqual(files[deepPath], "package deep\n")
        XCTAssertNil(files["truncated.go"], "the pax path should replace the header's own")
    }

    func testAGnuLongNameHeaderNamesTheEntryThatFollows() throws {
        let full = "example-main/\(deepPath)"
        let body = Data((full + "\0").utf8)
        let contents = Data("package deep\n".utf8)

        var tar = Data()
        tar.append(block(name: "././@LongLink", size: body.count, type: UInt8(ascii: "L")))
        tar.append(padded(body))
        tar.append(block(name: "example-main/truncated.go", size: contents.count, type: UInt8(ascii: "0")))
        tar.append(padded(contents))
        tar.append(Data(count: 1024))

        let files = try ProjectArchive.files(fromTar: tar)

        XCTAssertEqual(files[deepPath], "package deep\n")
    }

    /// A pax global header applies to the whole archive, not to the next entry,
    /// so it must not rename anything.
    func testAGlobalHeaderRenamesNothing() throws {
        let body = Data("30 comment=made by github\n".utf8)
        let contents = Data("package main\n".utf8)

        var tar = Data()
        tar.append(block(name: "pax_global_header", size: body.count, type: UInt8(ascii: "g")))
        tar.append(padded(body))
        tar.append(block(name: "example-main/main.go", size: contents.count, type: UInt8(ascii: "0")))
        tar.append(padded(contents))
        tar.append(Data(count: 1024))

        let files = try ProjectArchive.files(fromTar: tar)

        XCTAssertEqual(files["main.go"], "package main\n")
    }
}
