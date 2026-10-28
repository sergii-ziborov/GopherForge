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

    static let textExtensions = ProjectImportFilter.extensions
    static let textFilenames = ProjectImportFilter.names

    /// One file the editor can open. Beyond this a "file" is data, and putting
    /// it in a text view helps nobody.
    static let maximumFileBytes = 512 * 1024
    /// Enough for a real repository, bounded so a hostile one cannot ask for
    /// all of memory. Go source is kept ahead of notes and pages, because a
    /// budget spent on `.agents` and Markdown is how `cmd/` disappears and the
    /// module no longer builds. The archive reader enforces its own limit too.
    static let maximumFiles = 2_000

    /// The compressed archive's own ceiling.
    ///
    /// The reader below bounds what a tarball expands to, which is the defence
    /// against a decompression bomb — but it only gets to run once the whole
    /// download is already in memory. This is the bound on the download
    /// itself, so a repository that is simply enormous is refused before the
    /// phone has spent anything on it.
    static let maximumArchiveBytes = 64 * 1024 * 1024

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func importRepository(_ reference: GitHubRepositoryReference) async throws -> GopherForgeProject {
        let commit = try await resolvedCommit(for: reference)
        guard let url = GitHubRepositoryReference(
            owner: reference.owner, repository: reference.repository, reference: commit
        ).archiveURL() else { throw ImportError.badURL }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await BoundedDownload.load(
                url,
                limit: Self.maximumArchiveBytes,
                session: session
            )
        } catch is GoHTTPTransportError {
            throw ImportError.tooLarge
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

        return try project(fromArchive: data, reference: reference, commit: commit)
    }

    /// Split from the download so the filtering can be tested without a network.
    func project(
        fromArchive data: Data,
        reference: GitHubRepositoryReference,
        importedAt: Date = Date(),
        commit: String? = nil
    ) throws -> GopherForgeProject {
        let entries: [String: Data]
        var report = ProjectImportReport()
        report.archiveSHA256 = ProjectImportReport.digest(data)
        do {
            entries = try ProjectArchive.entries(fromTar: ProjectArchive.gunzip(data), report: &report)
        } catch ProjectArchive.ArchiveError.tooLarge {
            throw ImportError.tooLarge
        } catch {
            throw ImportError.notAnArchive
        }

        let files = ProjectImportFilter.select(entries, report: &report)

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
                commit: commit,
                importedAt: importedAt,
                importReport: report
            )
        )
    }

    /// Text worth opening, with Go source taken first when the file budget
    /// would otherwise fill up on documentation.
    static func keptFiles(in entries: [String: Data], limit: Int = maximumFiles) -> [String: String] {
        var report = ProjectImportReport()
        return ProjectImportFilter.select(entries, report: &report, maximumFiles: limit)
    }

    /// Fills in Go source a previous import left out, without replacing files
    /// the reader may already have edited.
    static func mergingMissingSource(
        into files: [String: String],
        from fresh: [String: String]
    ) -> [String: String] {
        var merged = files
        for (path, text) in fresh where SourceFileLimit.isBuildEssential(path) && merged[path] == nil {
            merged[path] = text
        }
        return merged
    }

    static func isWorthKeeping(path: String) -> Bool {
        ProjectImportFilter.reasonForPath(path) == nil
    }

    /// Resolve the requested branch/tag before download. Later restoration uses
    /// this immutable commit, never whatever a moving branch happens to contain.
    private func resolvedCommit(for reference: GitHubRepositoryReference) async throws -> String {
        struct Commit: Decodable { let sha: String }
        var url = URLComponents()
        url.scheme = "https"
        url.host = "api.github.com"
        url.path = "/repos/\(reference.owner)/\(reference.repository)/commits"
        url.queryItems = [URLQueryItem(name: "per_page", value: "1")]
        if let ref = reference.reference { url.queryItems?.append(URLQueryItem(name: "sha", value: ref)) }
        guard let endpoint = url.url else { throw ImportError.badURL }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("GopherForge", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await BoundedDownload.load(request, limit: 1_024 * 1_024, session: session)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: break
        case 404, 409, 422: throw ImportError.notFound(reference.displayName)
        case 403, 429: throw ImportError.rateLimited
        default: throw ImportError.unreachable("The repository revision could not be resolved.")
        }
        guard let sha = try JSONDecoder().decode([Commit].self, from: data).first?.sha,
              sha.count == 40, sha.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else { throw ImportError.unreachable("GitHub did not return a complete commit identifier.") }
        return sha
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
