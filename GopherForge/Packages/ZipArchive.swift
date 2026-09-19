import Foundation

/// A zip reader and writer that stays inside this app.
///
/// The only archive work this product needs is "read a module zip" and
/// "unpack the signed `goroot.zip`". That is not enough to justify linking
/// another third-party library into a binary Apple will scan. Written on
/// `Compression` the same way gzip is, so a zip is not a foreign binary.
enum ZipArchive {
    enum ZipError: Error, Equatable {
        case unreadable
        case unsupported
        case corrupt
        case tooLarge(Int)
        case unsafePath(String)
    }

    static let store: UInt16 = 0
    static let deflate: UInt16 = 8

    /// Regular files only, names as they appear in the archive.
    static func files(from data: Data, limit: Int) throws -> [String: Data] {
        var files: [String: Data] = [:]
        var total = 0
        for entry in try catalog(in: data) where !entry.isDirectory {
            let bytes = try extract(entry, from: data, remaining: limit - total)
            total += bytes.count
            guard total <= limit else { throw ZipError.tooLarge(total) }
            files[entry.path] = bytes
        }
        return files
    }

    static func unzip(file: URL, to destination: URL, limit: Int) throws {
        let data = try Data(contentsOf: file, options: [.mappedIfSafe])
        try unzip(data: data, to: destination, limit: limit)
    }

    static func unzip(data: Data, to destination: URL, limit: Int) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for (path, bytes) in try files(from: data, limit: limit) {
            guard let url = resolve(path, under: destination) else {
                throw ZipError.unsafePath(path)
            }
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: url, options: .atomic)
        }
    }

    /// Enough of a writer to test the reader and to pack a fixture. Deflate
    /// is the format `proxy.golang.org` and `goroot.zip` actually use.
    static func data(from files: [String: Data], compress: Bool = true) throws -> Data {
        var locals = Data()
        var central = Data()
        for path in files.keys.sorted() {
            let name = Data(path.utf8)
            guard name.count <= UInt16.max else { throw ZipError.unsupported }
            let raw = files[path] ?? Data()
            let crc = GzipStream.crc32(raw)
            let payload = compress && !raw.isEmpty ? try GzipStream.deflateRaw(raw) : raw
            let method = compress && !raw.isEmpty ? deflate : store
            let localOffset = UInt32(locals.count)
            locals.append(localHeader(name: name, method: method, crc: crc, compressed: payload.count, raw: raw.count))
            locals.append(name)
            locals.append(payload)
            central.append(
                centralHeader(
                    name: name,
                    method: method,
                    crc: crc,
                    compressed: payload.count,
                    raw: raw.count,
                    localOffset: localOffset
                )
            )
            central.append(name)
        }
        var out = locals
        let centralOffset = UInt32(out.count)
        out.append(central)
        out.append(endOfCentralDirectory(entries: files.count, size: UInt32(central.count), offset: centralOffset))
        return out
    }

    // MARK: - Catalog

    struct Entry: Equatable {
        var path: String
        var isDirectory: Bool
        var method: UInt16
        var crc32: UInt32
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
    }

    static func catalog(in data: Data) throws -> [Entry] {
        let eocd = try endRecord(in: data)
        guard eocd.offset + eocd.size <= data.count else { throw ZipError.corrupt }
        var cursor = eocd.offset
        var entries: [Entry] = []
        for _ in 0..<eocd.entries {
            guard cursor + 46 <= data.count, u32(data, cursor) == 0x0201_4b50 else {
                throw ZipError.corrupt
            }
            let flags = u16(data, cursor + 8)
            let method = u16(data, cursor + 10)
            let crc = u32(data, cursor + 16)
            let compressed = Int(u32(data, cursor + 20))
            let raw = Int(u32(data, cursor + 24))
            let nameLength = Int(u16(data, cursor + 28))
            let extraLength = Int(u16(data, cursor + 30))
            let commentLength = Int(u16(data, cursor + 32))
            let localOffset = Int(u32(data, cursor + 42))
            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd + extraLength + commentLength <= data.count else { throw ZipError.corrupt }
            let path = String(decoding: data.subdata(in: nameStart..<nameEnd), as: UTF8.self)
                .replacingOccurrences(of: "\\", with: "/")
            if flags & 1 != 0 { throw ZipError.unsupported }
            if method != store && method != deflate { throw ZipError.unsupported }
            entries.append(
                Entry(
                    path: path,
                    isDirectory: path.hasSuffix("/"),
                    method: method,
                    crc32: crc,
                    compressedSize: compressed,
                    uncompressedSize: raw,
                    localHeaderOffset: localOffset
                )
            )
            cursor = nameEnd + extraLength + commentLength
        }
        return entries
    }

    static func extract(_ entry: Entry, from data: Data, remaining: Int) throws -> Data {
        guard remaining >= 0 else { throw ZipError.tooLarge(entry.uncompressedSize) }
        guard entry.localHeaderOffset + 30 <= data.count, u32(data, entry.localHeaderOffset) == 0x0403_4b50 else {
            throw ZipError.corrupt
        }
        let nameLength = Int(u16(data, entry.localHeaderOffset + 26))
        let extraLength = Int(u16(data, entry.localHeaderOffset + 28))
        let dataStart = entry.localHeaderOffset + 30 + nameLength + extraLength
        let dataEnd = dataStart + entry.compressedSize
        guard dataEnd <= data.count else { throw ZipError.corrupt }
        let payload = data.subdata(in: dataStart..<dataEnd)
        let raw: Data
        switch entry.method {
        case store:
            raw = payload
        case deflate:
            do {
                raw = try GzipStream.inflateRaw(payload, limit: min(entry.uncompressedSize, remaining))
            } catch GzipStream.GzipError.tooLarge(let count) {
                throw ZipError.tooLarge(count)
            } catch {
                throw ZipError.corrupt
            }
        default:
            throw ZipError.unsupported
        }
        guard raw.count == entry.uncompressedSize else { throw ZipError.corrupt }
        guard GzipStream.crc32(raw) == entry.crc32 else { throw ZipError.corrupt }
        return raw
    }

    // MARK: - End of central directory

    private struct EndRecord {
        var entries: Int
        var size: Int
        var offset: Int
    }

    private static func endRecord(in data: Data) throws -> EndRecord {
        // The comment is at most 64 KiB, so the signature lives in the tail.
        let start = max(0, data.count - 22 - 65_535)
        var index = data.count - 22
        while index >= start {
            if u32(data, index) == 0x0605_4b50 {
                let comment = Int(u16(data, index + 20))
                if index + 22 + comment == data.count {
                    let entries = Int(u16(data, index + 10))
                    let size = Int(u32(data, index + 12))
                    let offset = Int(u32(data, index + 16))
                    if entries == 0xFFFF || size == 0xFFFF_FFFF || offset == 0xFFFF_FFFF {
                        throw ZipError.unsupported
                    }
                    return EndRecord(entries: entries, size: size, offset: offset)
                }
            }
            index -= 1
        }
        throw ZipError.unreadable
    }

    // MARK: - Headers

    private static func localHeader(
        name: Data,
        method: UInt16,
        crc: UInt32,
        compressed: Int,
        raw: Int
    ) -> Data {
        var header = Data(count: 30)
        put32(&header, 0, 0x0403_4b50)
        put16(&header, 4, 20)
        put16(&header, 8, method)
        put32(&header, 14, crc)
        put32(&header, 18, UInt32(compressed))
        put32(&header, 22, UInt32(raw))
        put16(&header, 26, UInt16(name.count))
        return header
    }

    private static func centralHeader(
        name: Data,
        method: UInt16,
        crc: UInt32,
        compressed: Int,
        raw: Int,
        localOffset: UInt32
    ) -> Data {
        var header = Data(count: 46)
        put32(&header, 0, 0x0201_4b50)
        put16(&header, 4, 20)
        put16(&header, 6, 20)
        put16(&header, 10, method)
        put32(&header, 16, crc)
        put32(&header, 20, UInt32(compressed))
        put32(&header, 24, UInt32(raw))
        put16(&header, 28, UInt16(name.count))
        put32(&header, 42, localOffset)
        return header
    }

    private static func endOfCentralDirectory(entries: Int, size: UInt32, offset: UInt32) -> Data {
        var header = Data(count: 22)
        put32(&header, 0, 0x0605_4b50)
        put16(&header, 8, UInt16(entries))
        put16(&header, 10, UInt16(entries))
        put32(&header, 12, size)
        put32(&header, 16, offset)
        return header
    }

    static func resolve(_ relativePath: String, under root: URL) -> URL? {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"),
              !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            return nil
        }
        return components.reduce(root) { $0.appendingPathComponent(String($1)) }
    }

    // MARK: - Little-endian

    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func put16(_ data: inout Data, _ offset: Int, _ value: UInt16) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8(value >> 8)
    }

    private static func put32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
