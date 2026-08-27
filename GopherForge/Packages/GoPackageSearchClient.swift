import Foundation

/// Searches the Go ecosystem for a module.
///
/// The Go module proxy resolves a path you already know and has no search. The
/// one public endpoint that does search across ecosystems is deps.dev's, and
/// it matches on **package names** rather than descriptions — "uuid" finds
/// `github.com/google/uuid`, "http router" finds nothing. That is a real limit
/// and the UI says so rather than leaving someone to conclude the ecosystem is
/// empty.
struct GoPackageSearchClient: Sendable {
    struct Result: Identifiable, Equatable, Sendable {
        let path: String
        let defaultVersion: String?
        var id: String { path }
    }

    private struct Response: Decodable {
        struct Entry: Decodable {
            let kind: String?
            let name: String?
            let system: String?
            let defaultVersion: String?
        }
        let results: [Entry]?
    }

    let baseURL: URL
    private let transport: any GoHTTPTransport

    init(
        baseURL: URL = URL(string: "https://deps.dev")!,
        transport: any GoHTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.transport = transport
    }

    /// Never throws. Search is a convenience over typing a module path in full,
    /// and a search service being down must not be the thing that stops
    /// someone installing a package they can name.
    func search(_ query: String) async -> [Result] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("_/search"),
            resolvingAgainstBaseURL: false
        ) else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "system", value: "GO"),
        ]
        guard let url = components.url,
              let (data, status) = try? await transport.get(url), status == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data)
        else {
            return []
        }

        return Self.goResults(in: decoded.results ?? [])
    }

    /// The endpoint answers across every ecosystem it knows and the `system`
    /// parameter does not narrow it, so the filtering happens here. A result
    /// whose name is not a module path is dropped: it cannot be installed, and
    /// offering it would only produce a failure later.
    private static func goResults(in entries: [Response.Entry]) -> [Result] {
        var seen: Set<String> = []
        var results: [Result] = []
        for entry in entries {
            guard entry.system == "GO", let name = entry.name,
                  GoPackageCatalog.looksLikeModulePath(name),
                  seen.insert(name).inserted
            else {
                continue
            }
            results.append(
                Result(
                    path: name,
                    defaultVersion: entry.defaultVersion.flatMap { $0.isEmpty ? nil : $0 }
                )
            )
        }
        return results
    }
}
