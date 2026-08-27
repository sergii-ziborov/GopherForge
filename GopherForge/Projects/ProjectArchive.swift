import Foundation

/// Packs a project into a gzipped tar, and reads one back.
///
/// A tar.gz rather than a zip or the app's own package format, because this is
/// the archive the rest of the world already opens: `tar xzf` on a laptop, a
/// double-click on a Mac, an attachment anywhere. The point of exporting is
/// that the project stops being locked inside this app.
///
/// Written by hand rather than shelled out to, because there is no shell here
/// — and tar's format is a header per file and nothing else, which is less code
/// than any dependency would be.
enum ProjectArchive {
    enum ArchiveError: Error, Equatable {
        case pathTooLong(String)
        case truncated
        case notATar
        case tooLarge(Int)
    }

    /// Generous for source, small enough that a malformed archive cannot ask
    /// for all of memory.
    static let maximumUncompressedBytes = 32 * 1024 * 1024
    private static let blockSize = 512

    // MARK: - Writing

    /// `files` are project-relative; they are stored under `root/` so unpacking
    /// creates a directory rather than scattering files into the current one.
    static func tar(files: [String: String], root: String) throws -> Data {
        var out = Data()
        for path in files.keys.sorted() {
            let name = "\(root)/\(path)"
            guard name.utf8.count <= 99 else { throw ArchiveError.pathTooLong(name) }
            let contents = Data((files[path] ?? "").utf8)
            out.append(header(name: name, size: contents.count))
            out.append(contents)
            out.append(padding(after: contents.count))
        }
        // Two empty blocks end a tar, and readers that do not see them treat
        // the archive as truncated.
        out.append(Data(count: blockSize * 2))
        return out
    }

    static func gzip(_ data: Data) throws -> Data {
        try GzipStream.compress(data)
    }

    // MARK: - Reading

    static func files(fromTar data: Data) throws -> [String: String] {
        guard data.count >= blockSize else { throw ArchiveError.notATar }
        var files: [String: String] = [:]
        var offset = 0
        var total = 0

        while offset + blockSize <= data.count {
            let block = data.subdata(in: offset..<(offset + blockSize))
            if block.allSatisfy({ $0 == 0 }) { break }
            guard let entry = Entry(block: block) else { throw ArchiveError.notATar }
            offset += blockSize

            let end = offset + entry.size
            guard end <= data.count else { throw ArchiveError.truncated }
            total += entry.size
            guard total <= maximumUncompressedBytes else { throw ArchiveError.tooLarge(total) }

            if entry.isFile, let relative = projectPath(from: entry.name) {
                files[relative] = String(decoding: data.subdata(in: offset..<end), as: UTF8.self)
            }
            offset = end + paddingLength(after: entry.size)
        }

        return files
    }

    static func gunzip(_ data: Data) throws -> Data {
        try GzipStream.decompress(data, limit: maximumUncompressedBytes)
    }

    /// Drops the archive's own top directory and refuses anything that would
    /// escape it. An archive is untrusted input even when the app wrote it.
    static func projectPath(from name: String) -> String? {
        let components = name.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.count > 1,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              !name.hasPrefix("/")
        else {
            return nil
        }
        return components.dropFirst().joined(separator: "/")
    }

    // MARK: - Blocks

    private struct Entry {
        let name: String
        let size: Int
        let isFile: Bool

        init?(block: Data) {
            func field(_ range: Range<Int>) -> String {
                String(decoding: block.subdata(in: range), as: UTF8.self)
                    .prefix(while: { $0 != "\0" })
                    .trimmingCharacters(in: .whitespaces)
            }
            let name = field(0..<100)
            guard !name.isEmpty, let size = Int(field(124..<136), radix: 8) else { return nil }
            self.name = name
            self.size = size
            let type = block[block.startIndex + 156]
            isFile = type == UInt8(ascii: "0") || type == 0
        }
    }

    private static func header(name: String, size: Int) -> Data {
        var block = [UInt8](repeating: 0, count: blockSize)

        func write(_ text: String, at offset: Int, width: Int) {
            for (index, byte) in Array(text.utf8).prefix(width - 1).enumerated() {
                block[offset + index] = byte
            }
        }

        write(name, at: 0, width: 100)
        write("0000644", at: 100, width: 8)
        write("0000000", at: 108, width: 8)
        write("0000000", at: 116, width: 8)
        write(String(format: "%011o", size), at: 124, width: 12)
        // A fixed timestamp: an export of the same project should produce the
        // same bytes, so two exports can be compared.
        write(String(format: "%011o", 0), at: 136, width: 12)
        block[156] = UInt8(ascii: "0")
        write("ustar", at: 257, width: 6)
        write("00", at: 263, width: 3)

        // The checksum is computed with its own field read as spaces.
        for index in 148..<156 { block[index] = UInt8(ascii: " ") }
        let checksum = block.reduce(0) { $0 + Int($1) }
        write(String(format: "%06o", checksum), at: 148, width: 8)
        block[154] = 0
        block[155] = UInt8(ascii: " ")

        return Data(block)
    }

    private static func paddingLength(after size: Int) -> Int {
        size % blockSize == 0 ? 0 : blockSize - (size % blockSize)
    }

    private static func padding(after size: Int) -> Data {
        Data(count: paddingLength(after: size))
    }
}
