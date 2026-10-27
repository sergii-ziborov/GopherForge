import Foundation

/// A dictionary-only origin: no TCP listener or access to the host filesystem.
struct OfflinePreviewResources {
    static let scheme = "gopherforge-preview"
    let url: URL
    let files: [String: String]

    func resource(for requestURL: URL) -> (body: Data, contentType: String)? {
        guard requestURL.scheme == Self.scheme, requestURL.host == url.host,
              !LocalSiteFiles.isUnsafe(requestURL.path),
              let recipeData = files[OfflineFrontendRecipe.path]?.data(using: .utf8),
              let recipe = try? JSONDecoder().decode(OfflineFrontendRecipe.self, from: recipeData) else { return nil }
        let path = LocalSiteFiles.sanitize(requestURL.path).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relative = path.isEmpty ? "index.html" : path
        if let text = files[recipe.output + "/" + relative] {
            return (Data(text.utf8), LocalSiteFiles.contentType(for: relative))
        }
        if path.hasPrefix("api/"), let resource = LocalSiteFiles.resource(for: "/" + path, in: files), resource.contentType == "application/json" {
            return resource
        }
        return nil
    }

    static let contentSecurityPolicy = """
    default-src 'none'; script-src gopherforge-preview: 'unsafe-inline'; \
    style-src gopherforge-preview: 'unsafe-inline'; connect-src gopherforge-preview:; \
    img-src gopherforge-preview: data: blob:; font-src gopherforge-preview: data:; \
    object-src 'none'; frame-src 'none'; worker-src 'none'; form-action 'none'; base-uri 'none'
    """
}
