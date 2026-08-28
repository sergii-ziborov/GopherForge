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
            let files = try ProjectArchive.files(
                fromTar: ProjectArchive.gunzip(try Data(contentsOf: url))
            )
            return GopherForgeProject(
                name: ProjectArchiveNaming.projectName(fromArchive: url.lastPathComponent),
                files: files,
                entryFile: ProjectArchiveNaming.entryFile(in: files),
                provenance: .files()
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
