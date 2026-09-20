import Darwin
import Foundation

/// Serves a project's HTML, CSS, JavaScript and JSON on loopback.
///
/// Guest programs cannot bind a port. These files are still a site, so the
/// host listens on 127.0.0.1 and the Output pane opens what that listen
/// produced. Only files already in the project are reachable.
final class LocalSiteServer: @unchecked Sendable {
    enum ServerError: Error, Equatable {
        case listenFailed
    }

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "gopherforge.site-preview")
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var files: [String: String] = [:]
    private(set) var port: UInt16 = 0

    var url: URL? {
        guard port > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(port)/")
    }

    var isListening: Bool { port > 0 }

    /// Updates the files and starts listening if this is the first publish.
    func publish(_ files: [String: String]) throws {
        lock.lock()
        self.files = files
        let needsListen = listenFD < 0
        lock.unlock()
        if needsListen {
            try startListening()
        }
    }

    func stop() {
        lock.lock()
        acceptSource?.cancel()
        acceptSource = nil
        listenFD = -1
        port = 0
        files = [:]
        lock.unlock()
    }

    private func startListening() throws {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ServerError.listenFailed }

        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = in_addr(s_addr: UInt32(0x7F00_0001).bigEndian)
        addr.sin_port = 0

        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, Darwin.listen(fd, 16) == 0 else {
            Darwin.close(fd)
            throw ServerError.listenFailed
        }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard named == 0 else {
            Darwin.close(fd)
            throw ServerError.listenFailed
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptClient(from: fd)
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()

        lock.lock()
        listenFD = fd
        acceptSource = source
        port = UInt16(bigEndian: assigned.sin_port)
        lock.unlock()
    }

    private func acceptClient(from listenFD: Int32) {
        var addr = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let client = withUnsafeMutablePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.accept(listenFD, $0, &length)
            }
        }
        guard client >= 0 else { return }
        var noSigPipe: Int32 = 1
        _ = setsockopt(
            client, SOL_SOCKET, SO_NOSIGPIPE,
            &noSigPipe, socklen_t(MemoryLayout<Int32>.size)
        )
        queue.async { [weak self] in
            self?.serve(client)
            Darwin.close(client)
        }
    }

    private func serve(_ fd: Int32) {
        var collected = Data()
        var chunk = [UInt8](repeating: 0, count: 4 * 1024)
        while collected.count < 32 * 1024 {
            let read = Darwin.recv(fd, &chunk, chunk.count, 0)
            guard read > 0 else { break }
            collected.append(contentsOf: chunk.prefix(Int(read)))
            if collected.range(of: Data("\r\n\r\n".utf8)) != nil { break }
        }
        guard !collected.isEmpty else { return }
        let request = String(decoding: collected, as: UTF8.self)
        let response = self.response(for: request)
        response.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var sent = 0
            while sent < bytes.count {
                let count = Darwin.send(fd, base.advanced(by: sent), bytes.count - sent, 0)
                guard count > 0 else { break }
                sent += count
            }
        }
    }

    private func response(for header: String) -> Data {
        let requestLine = header
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = requestLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let rawPath = parts.dropFirst().first.map(String.init) ?? "/"
        guard method == "GET" || method == "HEAD" else {
            return http(status: 405, type: "text/plain", body: Data("method not allowed".utf8))
        }
        lock.lock()
        let files = self.files
        lock.unlock()
        guard let resource = LocalSiteFiles.resource(for: rawPath, in: files) else {
            return http(status: 404, type: "text/plain; charset=utf-8", body: Data("not found".utf8))
        }
        if method == "HEAD" {
            return http(status: 200, type: resource.contentType, body: Data())
        }
        return http(status: 200, type: resource.contentType, body: resource.body)
    }

    private func http(status: Int, type: String, body: Data) -> Data {
        let reason = status == 200 ? "OK" : status == 404 ? "Not Found" : "Error"
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: \(type)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "Cache-Control: no-store\r\n"
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}

/// Maps a request path onto a file already in the project.
enum LocalSiteFiles {
    static func isSite(_ files: [String: String]) -> Bool {
        files.keys.contains {
            let name = $0.lowercased()
            return name.hasSuffix(".html") || name.hasSuffix(".htm")
        }
    }

    static func resource(
        for rawPath: String,
        in files: [String: String]
    ) -> (body: Data, contentType: String)? {
        if isUnsafe(rawPath) { return nil }
        let path = sanitize(rawPath)
        for candidate in candidates(for: path) {
            if isWebResource(candidate), let text = files[candidate] {
                return (Data(text.utf8), contentType(for: candidate))
            }
        }
        return nil
    }

    static func isUnsafe(_ rawPath: String) -> Bool {
        let decoded = rawPath.removingPercentEncoding ?? rawPath
        return decoded.contains("..") || decoded.contains("\\")
    }

    static func sanitize(_ rawPath: String) -> String {
        let withoutQuery = rawPath.split(separator: "?").first.map(String.init) ?? rawPath
        return withoutQuery.removingPercentEncoding ?? withoutQuery
    }

    static func candidates(for path: String) -> [String] {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.isEmpty {
            return ["web/index.html", "index.html", "static/index.html"]
        }
        return [
            trimmed,
            "web/\(trimmed)",
            "web/\(trimmed).html",
            "web/\(trimmed).json",
            "\(trimmed).html",
            "static/\(trimmed)",
        ]
    }

    static func contentType(for path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "html", "htm": "text/html; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "js", "mjs": "text/javascript; charset=utf-8"
        case "json": "application/json"
        case "svg": "image/svg+xml"
        default: "text/plain; charset=utf-8"
        }
    }

    private static func isWebResource(_ path: String) -> Bool {
        switch (path as NSString).pathExtension.lowercased() {
        case "html", "htm", "css", "js", "mjs", "json", "svg": true
        default: false
        }
    }
}
