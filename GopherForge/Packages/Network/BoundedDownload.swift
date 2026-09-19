import Foundation

/// Loads an HTTP body, refusing one that is too large before it is all in
/// memory.
///
/// Both places that download something — the Go module proxy and the GitHub
/// importer — checked the size only once the whole response had arrived. Every
/// limit below them is sound: the module archive validates its own prefix and
/// bounds what it expands to, and the tarball reader bounds decompressed bytes,
/// file count and paths. But all of that runs after the bytes are already
/// held, so the ceiling was on what was kept rather than on what was fetched.
enum BoundedDownload {
    static func load(
        _ url: URL,
        limit: Int,
        session: URLSession
    ) async throws -> (Data, URLResponse) {
        try await load(URLRequest(url: url), limit: limit, session: session)
    }

    static func load(
        _ request: URLRequest,
        limit: Int,
        session: URLSession
    ) async throws -> (Data, URLResponse) {
        let (stream, response) = try await session.bytes(for: request)

        // What the server says it is about to send. Refusing here is the
        // difference between not downloading something and downloading it
        // before deciding not to keep it.
        if let http = response as? HTTPURLResponse,
           http.expectedContentLength != NSURLSessionTransferSizeUnknown,
           http.expectedContentLength > Int64(limit) {
            stream.task.cancel()
            throw GoHTTPTransportError.tooLarge(
                bytes: Int(clamping: http.expectedContentLength),
                declared: true
            )
        }

        // A declared length is not a promise, and a chunked response declares
        // nothing at all, so the bytes are counted as they arrive.
        var data = Data()
        var block = [UInt8]()
        block.reserveCapacity(blockSize)
        var total = 0

        for try await byte in stream {
            total += 1
            if total > limit {
                stream.task.cancel()
                throw GoHTTPTransportError.tooLarge(bytes: total, declared: false)
            }
            block.append(byte)
            if block.count == blockSize {
                data.append(contentsOf: block)
                block.removeAll(keepingCapacity: true)
            }
        }
        data.append(contentsOf: block)

        return (data, response)
    }

    /// Appending in blocks rather than per byte. The sequence yields bytes one
    /// at a time whatever we do; the `Data` growth does not have to.
    private static let blockSize = 64 * 1024
}
