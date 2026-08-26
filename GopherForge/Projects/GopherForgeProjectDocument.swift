import Foundation
import UniformTypeIdentifiers

/// The `.gopherforgeproject` package.
///
/// A directory package rather than an archive: exported to Files it stays
/// browsable, and every source file is still a plain text file the user owns
/// and can open in anything else.
enum GopherForgeProjectDocument {
    static let contentType = UTType(exportedAs: "com.sergiiziborov.gopherforge.project")
    private static let manifestName = "gopherforge.json"

    private struct Manifest: Codable {
        let name: String
        let entryFile: String
        let provenance: GopherForgeProject.Provenance?
        let exportedAt: Date
    }

    enum DocumentError: LocalizedError, Equatable {
        case missingManifest
        case unreadableManifest

        var errorDescription: String? {
            switch self {
            case .missingManifest: "That package has no GopherForge manifest."
            case .unreadableManifest: "That package's manifest could not be read."
            }
        }
    }

    static func write(_ project: GopherForgeProject, to url: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        for (path, contents) in project.files {
            guard let fileURL = GoWorkspaceStager.resolve(relativePath: path, under: url) else {
                continue
            }
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: fileURL, options: .atomic)
        }

        let manifest = Manifest(
            name: project.name,
            entryFile: project.entryFile,
            provenance: project.provenance,
            exportedAt: Date()
        )
        try JSONEncoder.gopherForge
            .encode(manifest)
            .write(to: url.appending(path: manifestName), options: .atomic)
    }

    static func read(from url: URL) throws -> GopherForgeProject {
        let manifestURL = url.appending(path: manifestName)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw DocumentError.missingManifest
        }
        guard let manifest = try? JSONDecoder.gopherForge.decode(
            Manifest.self,
            from: Data(contentsOf: manifestURL)
        ) else {
            throw DocumentError.unreadableManifest
        }

        var files = try LocalProjectLoader().load(from: url).files
        files.removeValue(forKey: manifestName)

        return GopherForgeProject(
            name: manifest.name,
            files: files,
            entryFile: manifest.entryFile,
            provenance: manifest.provenance
        )
    }
}
