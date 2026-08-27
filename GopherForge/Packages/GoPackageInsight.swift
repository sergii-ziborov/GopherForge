import Foundation

/// What is known about a package beyond its name.
///
/// Every number here is sourced, none of it is invented. There is no ratings
/// service for Go modules and this product will not pretend otherwise: what it
/// shows is the repository's own popularity and the OpenSSF Scorecard, both
/// from deps.dev, and it says where they came from.
struct GoPackageInsight: Equatable, Sendable {
    /// OpenSSF Scorecard, 0 to 10. An automated assessment of a project's
    /// release and review practices — not of whether the code is any good.
    let scorecard: Double?
    let stars: Int?
    let forks: Int?
    let openIssues: Int?
    let license: String?
    let summary: String?
    /// The checks behind the score, worst first, so a low score can be read
    /// rather than merely obeyed.
    let checks: [Check]

    struct Check: Equatable, Sendable, Identifiable {
        let name: String
        /// 0 to 10, or nil where Scorecard reports -1 for "not applicable".
        let score: Double?
        var id: String { name }
    }

    static let unknown = GoPackageInsight(
        scorecard: nil, stars: nil, forks: nil, openIssues: nil,
        license: nil, summary: nil, checks: []
    )

    var hasAnything: Bool {
        scorecard != nil || stars != nil || license != nil || summary != nil
    }
}

/// Reads deps.dev, which aggregates the Go module proxy, the repository and
/// OpenSSF Scorecard.
struct GoPackageInsightClient: Sendable {
    private struct ProjectResponse: Decodable {
        struct Scorecard: Decodable {
            struct Check: Decodable {
                let name: String
                let score: Double?
            }
            let overallScore: Double?
            let checks: [Check]?
        }
        let starsCount: Int?
        let forksCount: Int?
        let openIssuesCount: Int?
        let license: String?
        let description: String?
        let scorecard: Scorecard?
    }

    let baseURL: URL
    private let transport: any GoHTTPTransport

    init(
        baseURL: URL = URL(string: "https://api.deps.dev")!,
        transport: any GoHTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.transport = transport
    }

    /// Never throws. Insight is decoration around a decision the user makes
    /// from the module path and version; a metadata service being down must not
    /// stop an install, and an empty panel says so honestly.
    func insight(forModulePath path: String) async -> GoPackageInsight {
        guard let projectID = Self.projectIdentifier(forModulePath: path) else { return .unknown }
        let escaped = projectID.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        ) ?? projectID
        let url = baseURL.appendingPathComponent("v3alpha/projects/\(escaped)")

        guard let (data, status) = try? await transport.get(url), status == 200,
              let decoded = try? JSONDecoder().decode(ProjectResponse.self, from: data)
        else {
            return .unknown
        }

        let checks = (decoded.scorecard?.checks ?? [])
            .map { GoPackageInsight.Check(name: $0.name, score: ($0.score ?? -1) < 0 ? nil : $0.score) }
            .sorted { ($0.score ?? 11) < ($1.score ?? 11) }

        return GoPackageInsight(
            scorecard: decoded.scorecard?.overallScore,
            stars: decoded.starsCount,
            forks: decoded.forksCount,
            openIssues: decoded.openIssuesCount,
            license: decoded.license,
            summary: decoded.description,
            checks: checks
        )
    }

    /// deps.dev keys projects by repository, so a module path with a version
    /// suffix or a subdirectory has to be reduced to `host/owner/repo` first.
    /// `github.com/foo/bar/v2/baz` is the project `github.com/foo/bar`.
    static func projectIdentifier(forModulePath path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 3 else { return nil }
        return parts.prefix(3).joined(separator: "/")
    }
}
