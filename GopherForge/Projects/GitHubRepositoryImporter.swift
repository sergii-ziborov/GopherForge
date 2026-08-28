import Foundation

/// Downloads a public GitHub repository and turns it into a project.
///
/// A snapshot rather than a clone: there is no git here, and a learner opening
/// somebody's example wants the code, not its history. The codeload endpoint
/// hands over exactly that as a gzipped tar, which the app already knows how to
/// read.
///
/// What arrives is untrusted, so the result is filtered rather than trusted:
/// only text files this app can actually show, only under a size the editor can
/// hold, and never a path that escapes the archive's own directory.
struct GitHubRepositoryImporter: Sendable {
    enum ImportError: LocalizedError, Equatable {
        case badURL
        case unreachable(String)
        case notFound(String)
        case rateLimited
        case notAnArchive
        case tooLarge
        case noGoSource(String)

        var errorDescription: String? {
            switch self {
            case .badURL:
                "That repository URL could not be turned into a download."
            case let .unreachable(detail):
                "The download failed: \(detail)"
            case let .notFound(name):
                "\(name) could not be found. It may be private, renamed, or the "
                    + "branch may not exist."
            case .rateLimited:
                "GitHub is rate limiting downloads from this network. Try again shortly."
            case .notAnArchive:
                "What GitHub returned was not a readable archive."
            case .tooLarge:
                "That repository is too large to open on device."
            case let .noGoSource(name):
                "\(name) has no Go source in it, so there is nothing here to build."
            }
        }
    }

    /// Extensions worth carrying into a project. Everything else — binaries,
    /// images, vendored archives — is dropped rather than shown as a screenful
    /// of replacement characters.
    static let textExtensions: Set<String> = [
        "go", "mod", "sum", "md", "txt", "json", "yaml", "yml", "toml", "gitignore",
    ]
    /// Files with no extension that are still worth reading.
    static let textFilenames: Set<String> = ["LICENSE", "NOTICE", "AUTHORS", "Makefile"]

    /// One file the editor can open. Beyond this a "file" is data, and putting
    /// it in a text view helps nobody.
    static let maximumFileBytes = 512 * 1024
    /// Enough for a real repository, bounded so a hostile one cannot ask for
    /// all of memory. The archive reader enforces its own limit as well.
    static let maximumFiles = 400

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func importRepository(_ reference: GitHubRepositoryReference) async throws -> GopherForgeProject {
        guard let url = reference.archiveURL() else { throw ImportError.badURL }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ImportError.unreachable(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 404: throw ImportError.notFound(reference.displayName)
            case 403, 429: throw ImportError.rateLimited
            case let code: throw ImportError.unreachable("HTTP \(code)")
            }
        }

        return try project(fromArchive: data, reference: reference)
    }

    /// Split from the download so the filtering can be tested without a network.
    func project(
        fromArchive data: Data,
        reference: GitHubRepositoryReference,
        importedAt: Date = Date()
    ) throws -> GopherForgeProject {
        let entries: [String: Data]
        do {
            entries = try ProjectArchive.entries(fromTar: ProjectArchive.gunzip(data))
        } catch ProjectArchive.ArchiveError.tooLarge {
            throw ImportError.tooLarge
        } catch {
            throw ImportError.notAnArchive
        }

        var files: [String: String] = [:]
        for path in entries.keys.sorted() {
            guard files.count < Self.maximumFiles else { break }
            guard Self.isWorthKeeping(path: path) else { continue }
            guard let body = entries[path], body.count <= Self.maximumFileBytes else { continue }
            // Invalid UTF-8 means it was not text after all, whatever the name
            // said. Dropped rather than mangled.
            guard let text = String(data: body, encoding: .utf8) else { continue }
            files[path] = text
        }

        guard files.keys.contains(where: { $0.hasSuffix(".go") }) else {
            throw ImportError.noGoSource(reference.displayName)
        }

        return GopherForgeProject(
            name: reference.repository,
            files: files,
            entryFile: Self.entryFile(in: files),
            provenance: GopherForgeProject.Provenance(
                source: .github,
                owner: reference.owner,
                repository: reference.repository,
                reference: reference.reference,
                commit: nil,
                importedAt: importedAt
            )
        )
    }

    static func isWorthKeeping(path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        // Repository furniture that is not the code and only adds noise to the
        // navigator.
        let ignoredDirectories = [".git/", ".github/", "testdata/", "vendor/"]
        if ignoredDirectories.contains(where: { path.hasPrefix($0) || path.contains("/\($0)") }) {
            return false
        }
        if textFilenames.contains(name) { return true }
        let ext = (name as NSString).pathExtension
        return !ext.isEmpty && textExtensions.contains(ext)
    }

    /// The file worth opening first: the package main with a func main in it,
    /// then any main.go, then whatever sorts first.
    static func entryFile(in files: [String: String]) -> String {
        let goFiles = files.keys.filter { $0.hasSuffix(".go") }.sorted()

        if let entry = goFiles.first(where: {
            let source = files[$0] ?? ""
            return source.contains("package main") && source.contains("func main(")
        }) {
            return entry
        }
        return goFiles.first(where: { $0 == "main.go" })
            ?? goFiles.first
            ?? files.keys.sorted().first
            ?? "main.go"
    }
}
