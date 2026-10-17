import Foundation

/// The URL the share extension uses to hand a repository to the app.
///
/// The extension can foreground this app only through a scheme the app
/// registered. The repository URL rides in the query so opening still works
/// if the shared queue was already drained.
enum GopherForgeLink {
    static let scheme = "gopherforge"

    static func importURL(repository rawURL: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "url", value: rawURL)]
        return components.url
    }

    static func repositoryURL(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == "import" else {
            return nil
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "url" }?
            .value
    }
}
