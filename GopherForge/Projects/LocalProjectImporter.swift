import Foundation

/// Opens whatever a person picked in the Files app.
///
/// Three shapes arrive here — this app's own document, an exported `.tar.gz`,
/// and a plain folder of Go source — and the extension is the only thing that
/// distinguishes them. Shared rather than inlined in a view so the "new
/// project" screen and the projects list cannot drift into reading the same
/// file differently.
enum LocalProjectImporter {
    static func load(at url: URL) throws -> GopherForgeProject {
        switch url.pathExtension.lowercased() {
        case "gopherforgeproject":
            return try GopherForgeProjectDocument.read(from: url)
        case "gz", "tgz":
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= GitHubRepositoryImporter.maximumArchiveBytes else { throw ProjectArchive.ArchiveError.tooLarge(size) }
            let data = try Data(contentsOf: url)
            guard data.count <= GitHubRepositoryImporter.maximumArchiveBytes else { throw ProjectArchive.ArchiveError.tooLarge(data.count) }
            var report = ProjectImportReport()
            report.archiveSHA256 = ProjectImportReport.digest(data)
            let entries = try ProjectArchive.entries(fromTar: ProjectArchive.gunzip(data), report: &report)
            let files = ProjectImportFilter.select(entries, report: &report)
            return GopherForgeProject(
                name: ProjectArchiveNaming.projectName(fromArchive: url.lastPathComponent),
                files: files,
                entryFile: ProjectArchiveNaming.entryFile(in: files),
                provenance: GopherForgeProject.Provenance(
                    source: .files, owner: nil, repository: nil, reference: nil,
                    commit: nil, importedAt: Date(), importReport: report
                )
            )
        default:
            return try LocalProjectLoader().load(from: url)
        }
    }

    /// Opens the security scope a picked file needs, and closes it whatever
    /// happens — a scope left open leaks a resource the system counts.
    static func loadPicked(at url: URL) throws -> GopherForgeProject {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        return try load(at: url)
    }
}
