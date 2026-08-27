import Foundation
import Compression

/// gzip, built on the system's raw deflate.
///
/// Apple's `Compression` framework speaks raw deflate but not gzip, which
/// differs only by a ten-byte header and an eight-byte trailer carrying a
/// CRC-32 and the length. Writing those here is a page of code; the alternative
/// is a dependency for a file format that has not changed since 1992.
enum GzipStream {
    enum GzipError: Error, Equatable {
        case notGzip
        case truncated
        case corrupt
        case tooLarge(Int)
    }

    private static let header: [UInt8] = [
        0x1f, 0x8b, // magic
        0x08,       // deflate
        0x00,       // no flags, so no name or comment follows
        0, 0, 0, 0, // no timestamp: the same input should give the same bytes
        0x00,       // no extra flags
        0xff,       // unknown operating system
    ]

    static func compress(_ data: Data) throws -> Data {
        var out = Data(header)
        out.append(try codec(data, operation: COMPRESSION_STREAM_ENCODE, limit: .max))
        var crc = crc32(data).littleEndian
        var size = UInt32(truncatingIfNeeded: data.count).littleEndian
        withUnsafeBytes(of: &crc) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: &size) { out.append(contentsOf: $0) }
        return out
    }

    static func decompress(_ data: Data, limit: Int) throws -> Data {
        guard data.count > header.count + 8,
              data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b
        else {
            throw GzipError.notGzip
        }
        guard data[data.startIndex + 2] == 0x08, data[data.startIndex + 3] == 0x00 else {
            // Flags mean a name, comment or extra field precedes the payload.
            // Nothing this app writes sets them, and guessing at one it did not
            // write is how a decoder starts reading the wrong offset.
            throw GzipError.corrupt
        }

        let body = data.subdata(in: (data.startIndex + header.count)..<(data.endIndex - 8))
        let out = try codec(body, operation: COMPRESSION_STREAM_DECODE, limit: limit)

        let trailer = data.suffix(8)
        let expected = trailer.prefix(4).reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        guard crc32(out) == expected else { throw GzipError.corrupt }
        return out
    }

    // MARK: - Deflate

    private static func codec(
        _ input: Data,
        operation: compression_stream_operation,
        limit: Int
    ) throws -> Data {
        guard !input.isEmpty else { return Data() }

        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var stream = compression_stream(
            dst_ptr: buffer, dst_size: bufferSize, src_ptr: buffer, src_size: 0, state: nil
        )
        guard compression_stream_init(&stream, operation, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK
        else {
            throw GzipError.corrupt
        }
        defer { compression_stream_destroy(&stream) }

        var out = Data()
        try input.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
            guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return }
            stream.src_ptr = base
            stream.src_size = input.count

            while true {
                stream.dst_ptr = buffer
                stream.dst_size = bufferSize
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produced = bufferSize - stream.dst_size
                if produced > 0 {
                    out.append(buffer, count: produced)
                    guard out.count <= limit else { throw GzipError.tooLarge(out.count) }
                }
                switch status {
                case COMPRESSION_STATUS_END: return
                case COMPRESSION_STATUS_OK: continue
                default: throw GzipError.corrupt
                }
            }
        }
        return out
    }

    /// The standard CRC-32, table built once.
    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}
