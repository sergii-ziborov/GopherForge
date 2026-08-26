import Foundation

/// A parsed public GitHub repository URL.
///
/// Parsing happens in the share extension as well as the app, so it lives in
/// shared code: a URL the extension accepted must be a URL the app can act on.
struct GitHubRepositoryReference: Equatable, Sendable {
    let owner: String
    let repository: String
    /// A branch, tag or commit, when the URL named one.
    let reference: String?

    var displayName: String { "\(owner)/\(repository)" }

    /// The codeload archive URL for a snapshot download.
    func archiveURL() -> URL? {
        let ref = reference ?? "HEAD"
        return URL(string: "https://codeload.github.com/\(owner)/\(repository)/tar.gz/\(ref)")
    }

    enum ParseError: LocalizedError, Equatable {
        case notAURL
        case notGitHub
        case missingRepository

        var errorDescription: String? {
            switch self {
            case .notAURL: "That does not look like a URL."
            case .notGitHub: "Only github.com repository URLs can be imported."
            case .missingRepository: "That GitHub URL does not name a repository."
            }
        }
    }

    static func parse(_ rawURL: String) throws -> GitHubRepositoryReference {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed), let host = components.host else {
            throw ParseError.notAURL
        }
        guard host == "github.com" || host == "www.github.com" else {
            throw ParseError.notGitHub
        }

        let parts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard parts.count >= 2 else { throw ParseError.missingRepository }

        let repository = parts[1].hasSuffix(".git")
            ? String(parts[1].dropLast(4))
            : parts[1]

        // /owner/repo/tree/<ref> and /owner/repo/commit/<sha> both name a ref.
        var reference: String?
        if parts.count >= 4, parts[2] == "tree" || parts[2] == "commit" {
            reference = parts[3...].joined(separator: "/")
        }

        return GitHubRepositoryReference(
            owner: parts[0],
            repository: repository,
            reference: reference
        )
    }
}
