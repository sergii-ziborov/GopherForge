import Foundation

/// Every project the owner has, persisted as one JSON document.
///
/// An actor because the workspace, the importer and the share queue all record
/// into it, and the list must never be half-written.
///
/// Nothing is evicted. It used to keep the ten most recent and drop the rest,
/// which is defensible for a "recent" strip and indefensible for the only place
/// a project exists: the eleventh project someone made was deleted by opening
/// an eleventh project. The cost is that this document holds the source of
/// every project, so it grows with the library — acceptable while projects are
/// Go source measured in kilobytes, and the thing to revisit first if that
/// stops being true.
actor ProjectLibrary {
    private struct State: Codable {
        var items: [ProjectLibraryItem]
    }

    private let storageURL: URL
    private var cachedState: State?

    /// The library the app uses.
    ///
    /// Shared for the same reason the progress store is: the workspace records
    /// a build into one instance and the dashboard reads from another, and an
    /// actor holding a cache answers the second one from whatever it had read
    /// before. The result was a Recent list that went stale the moment you
    /// built something.
    static let shared = ProjectLibrary(
        storageURL: LaunchOptions.usesEmptyLibrary ? ProjectLibrary.throwawayURL : nil
    )

    /// Somewhere a run under `-GopherForgeEmptyLibrary` can write without
    /// touching the device's real library.
    private static var throwawayURL: URL {
        FileManager.default.temporaryDirectory
            .appending(
                path: "gopherforge-empty-library-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
            .appending(path: "projects.json")
    }

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.storageURL = applicationSupport
                .appending(path: "GopherForge", directoryHint: .isDirectory)
                .appending(path: "recent-projects.json")
        }
    }

    func items() throws -> [ProjectLibraryItem] {
        try state().items.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    func project(id: UUID) throws -> ProjectLibraryItem? {
        try state().items.first { $0.id == id }
    }

    @discardableResult
    func record(
        project: GopherForgeProject,
        lastBuild: ProjectBuildRecord?
    ) throws -> [ProjectLibraryItem] {
        var current = try state()
        let key = projectKey(project)

        if let index = current.items.firstIndex(where: { projectKey($0.project) == key }) {
            current.items[index].project = project
            current.items[index].lastOpenedAt = Date()
            if let lastBuild { current.items[index].lastBuild = lastBuild }
        } else {
            current.items.append(
                ProjectLibraryItem(
                    id: UUID(),
                    project: project,
                    lastOpenedAt: Date(),
                    lastBuild: lastBuild
                )
            )
        }

        current.items.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        try persist(current)
        return current.items
    }

    /// Files a project: its name, folder, tags, star and one-line summary.
    ///
    /// Everything the owner controls in one call, so an edit sheet is one write
    /// rather than five and cannot leave the library half-renamed.
    @discardableResult
    func update(
        id: UUID,
        name: String? = nil,
        folder: String? = nil,
        tags: [String]? = nil,
        isFavorite: Bool? = nil,
        summary: String? = nil
    ) throws -> [ProjectLibraryItem] {
        var current = try state()
        guard let index = current.items.firstIndex(where: { $0.id == id }) else {
            return try items()
        }

        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                current.items[index].project = current.items[index].project.renamed(to: trimmed)
            }
        }
        if let folder { current.items[index].folder = ProjectLibraryItem.normalizedFolder(folder) }
        if let tags { current.items[index].tags = tags.isEmpty ? nil : tags }
        if let isFavorite { current.items[index].isFavorite = isFavorite }
        if let summary {
            let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            current.items[index].summary = trimmed.isEmpty ? nil : trimmed
        }

        try persist(current)
        return try items()
    }

    @discardableResult
    func setFavorite(id: UUID, _ isFavorite: Bool) throws -> [ProjectLibraryItem] {
        try update(id: id, isFavorite: isFavorite)
    }

    @discardableResult
    func move(id: UUID, toFolder folder: String?) throws -> [ProjectLibraryItem] {
        try update(id: id, folder: folder ?? "")
    }

    /// The folders in use, named once each and sorted the way a person reads a
    /// list rather than the way ASCII sorts one.
    func folders() throws -> [String] {
        let labels = try state().items.map(\.folderLabel)
        return Array(Set(labels)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    @discardableResult
    func remove(id: UUID) throws -> [ProjectLibraryItem] {
        var current = try state()
        current.items.removeAll { $0.id == id }
        try persist(current)
        return current.items.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    // MARK: - Storage

    /// A project is identified by its name and provenance rather than by a
    /// generated id, so reopening the same folder updates the entry instead of
    /// growing a duplicate.
    private func projectKey(_ project: GopherForgeProject) -> String {
        let provenance = project.provenance
        let origin = [
            provenance?.source.rawValue,
            provenance?.owner,
            provenance?.repository,
            provenance?.reference,
        ]
        .compactMap { $0 }
        .joined(separator: "/")
        return "\(project.name)#\(origin)"
    }

    private func state() throws -> State {
        if let cachedState { return cachedState }
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            let empty = State(items: [])
            cachedState = empty
            return empty
        }
        let data = try Data(contentsOf: storageURL)
        let decoded = try JSONDecoder.gopherForge.decode(State.self, from: data)
        cachedState = decoded
        return decoded
    }

    private func persist(_ state: State) throws {
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.gopherForge.encode(state).write(to: storageURL, options: .atomic)
        cachedState = state
    }
}
