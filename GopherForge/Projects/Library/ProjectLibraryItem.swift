import Foundation

/// One project as the library holds it: the project itself, when it was last
/// opened, how its last build went, and how its owner has filed it.
///
/// The filing lives here rather than on `GopherForgeProject` on purpose. A
/// folder and a star are facts about someone's library, not about the Go code:
/// the compiler, the templates and the archive format have no business knowing
/// them, and an exported `.tar.gz` opened on another device should not arrive
/// carrying somebody else's folder names.
///
/// Every field added after the first release is optional. A non-optional new
/// key turns every existing install's library into a decode failure, which is a
/// worse bug than a missing feature.
struct ProjectLibraryItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var project: GopherForgeProject
    var lastOpenedAt: Date
    var lastBuild: ProjectBuildRecord?
    /// The folder its owner filed it under, or nil for the loose ones.
    var folder: String?
    var tags: [String]?
    var isFavorite: Bool?
    /// A line the owner wrote about it, shown under the name.
    var summary: String?

    init(
        id: UUID,
        project: GopherForgeProject,
        lastOpenedAt: Date,
        lastBuild: ProjectBuildRecord? = nil,
        folder: String? = nil,
        tags: [String]? = nil,
        isFavorite: Bool? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.project = project
        self.lastOpenedAt = lastOpenedAt
        self.lastBuild = lastBuild
        self.folder = folder
        self.tags = tags
        self.isFavorite = isFavorite
        self.summary = summary
    }

    var favorite: Bool { isFavorite ?? false }

    var tagList: [String] { tags ?? [] }

    /// What an unfiled project is filed under, so grouping has one bucket for
    /// them rather than a nil case every caller has to remember.
    static let looseFolder = "Unfiled"

    var folderLabel: String {
        ProjectLibraryItem.normalizedFolder(folder) ?? ProjectLibraryItem.looseFolder
    }

    /// Everything a search should look at, lowercased once rather than at every
    /// keystroke for every project.
    var searchHaystack: String {
        var parts = [project.name, folderLabel]
        parts.append(contentsOf: tagList)
        if let summary { parts.append(summary) }
        if let module = project.module { parts.append(module.modulePath) }
        // The file names too: someone looking for the project with the parser
        // in it remembers `parser.go` more reliably than what they called the
        // project six weeks ago.
        parts.append(contentsOf: project.files.keys)
        return parts.joined(separator: " ").lowercased()
    }

    func matches(_ needle: String) -> Bool {
        needle.isEmpty || searchHaystack.contains(needle)
    }

    /// Trimmed, and empty means unfiled rather than a folder with no name.
    static func normalizedFolder(_ folder: String?) -> String? {
        guard let folder else { return nil }
        let trimmed = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Split on commas, trimmed, lowercased, de-duplicated, order kept. Two
    /// tags differing only in case are one tag; a filter that treats them as
    /// two silently hides projects.
    static func normalizedTags(_ raw: String) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for piece in raw.split(separator: ",") {
            let tag = piece.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !tag.isEmpty, seen.insert(tag).inserted else { continue }
            result.append(tag)
        }
        return result
    }
}
