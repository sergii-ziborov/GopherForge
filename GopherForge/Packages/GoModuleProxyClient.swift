import Foundation

/// Talks to a Go module proxy — by default the official one.
///
/// This is the only part of GopherForge that uses the network, and it is used
/// at exactly one moment: while installing a package. Once a module is
/// vendored, every build is offline again, which is why the compiler still runs
/// with `GOPROXY=off`.
struct GoModuleProxyClient: Sendable {
    /// The published limits, enforced before a download rather than after: a
    /// phone should not spend a hundred megabytes finding out a module is too
    /// big to be worth vendoring.
    static let maximumArchiveBytes = 24 * 1024 * 1024
    static let maximumMetadataBytes = 512 * 1024

    enum ProxyError: Error, Equatable {
        case notFound(String)
        case badStatus(Int, String)
        case tooLarge(Int)
        case malformedResponse(String)
    }

    struct LatestVersion: Decodable, Equatable, Sendable {
        let Version: String
        let Time: String?
    }

    let baseURL: URL
    private let transport: any GoHTTPTransport

    init(
        baseURL: URL = URL(string: "https://proxy.golang.org")!,
        transport: any GoHTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func latestVersion(of path: String) async throws -> String {
        let data = try await get(escaped(path) + "/@latest", limit: Self.maximumMetadataBytes)
        guard let latest = try? JSONDecoder().decode(LatestVersion.self, from: data) else {
            throw ProxyError.malformedResponse("@latest for \(path)")
        }
        return latest.Version
    }

    /// Newest first. The proxy returns them unordered, and a version list that
    /// is not sorted makes the newest release hard to find in a long list.
    func versions(of path: String) async throws -> [String] {
        let data = try await get(escaped(path) + "/@v/list", limit: Self.maximumMetadataBytes)
        let lines = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
        return GoSemanticVersion.sortedNewestFirst(lines)
    }

    func goModFile(for reference: GoModuleReference) async throws -> String {
        let data = try await get(
            escaped(reference.path) + "/@v/\(reference.version).mod",
            limit: Self.maximumMetadataBytes
        )
        return String(decoding: data, as: UTF8.self)
    }

    func archive(for reference: GoModuleReference) async throws -> Data {
        try await get(
            escaped(reference.path) + "/@v/\(reference.version).zip",
            limit: Self.maximumArchiveBytes
        )
    }

    // MARK: - Transport

    private func get(_ path: String, limit: Int) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        let (data, status) = try await transport.get(url)
        switch status {
        case 200:
            guard data.count <= limit else { throw ProxyError.tooLarge(data.count) }
            return data
        case 404, 410:
            throw ProxyError.notFound(path)
        default:
            throw ProxyError.badStatus(status, path)
        }
    }

    /// Module paths are case-folded for the proxy: an upper-case letter becomes
    /// `!` followed by its lower-case form, so `github.com/BurntSushi/toml`
    /// is fetched as `github.com/!burnt!sushi/toml`. Without this, every module
    /// with a capital letter in its path fails to resolve.
    private func escaped(_ path: String) -> String {
        var escaped = ""
        for character in path {
            if character.isUppercase {
                escaped.append("!")
                escaped.append(Character(character.lowercased()))
            } else {
                escaped.append(character)
            }
        }
        return escaped
    }
}

/// The one thing that touches the network, behind a protocol so every client
/// above it is testable without one.
protocol GoHTTPTransport: Sendable {
    func get(_ url: URL) async throws -> (Data, Int)
}

struct URLSessionTransport: GoHTTPTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get(_ url: URL) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        // The proxy serves the right thing without content negotiation, and a
        // plain identity encoding keeps the archive bytes exactly as hashed.
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}
