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
        // A share sheet often wraps the link in a sentence. The repository is
        // the GitHub URL inside that sentence, not the sentence itself.
        let candidate = embeddedGitHubURL(in: trimmed) ?? trimmed
        guard let components = URLComponents(string: candidate), let host = components.host?.lowercased() else {
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

    /// The first `github.com` link in a shared message, if the text is not
    /// itself that URL.
    private static func embeddedGitHubURL(in text: String) -> String? {
        guard text.contains("github.com") else { return nil }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url, let host = url.host?.lowercased(),
                  host == "github.com" || host == "www.github.com"
            else { continue }
            let parts = url.path.split(separator: "/").filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            return url.absoluteString
        }
        return nil
    }
}
