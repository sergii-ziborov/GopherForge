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

    private var storageURL: URL
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
        self.storageURL = storageURL ?? ProjectLibraryLocation.fileURL()
    }

    /// Moves the library JSON into a folder the owner picked (Files or
    /// iCloud Drive) and remembers that folder for the next launch.
    func adoptFolder(_ folder: URL) throws -> [ProjectLibraryItem] {
        let current = try state()
        try ProjectLibraryLocation.remember(folder: folder)
        storageURL = ProjectLibraryLocation.fileURL()
        try persist(current)
        return try items()
    }

    func useOnDeviceLibrary() throws -> [ProjectLibraryItem] {
        let current = try state()
        ProjectLibraryLocation.forgetChosenFolder()
        storageURL = ProjectLibraryLocation.defaultFileURL()
        try persist(current)
        return try items()
    }

    var storesInChosenFolder: Bool {
        ProjectLibraryLocation.usesChosenFolder
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
        let id = UUID()
        _ = try recordSource(id: id, revision: 0, project: project)
        if let lastBuild { try recordBuild(id: id, result: lastBuild) }
        return try items()
    }

    /// Source writes are keyed by the library UUID, never by a mutable name.
    /// A delayed save from an older editor revision cannot replace newer code.
    @discardableResult
    func recordSource(id: UUID, revision: UInt64, project: GopherForgeProject) throws -> ProjectLibraryItem {
        var current = try state()
        if let index = current.items.firstIndex(where: { $0.id == id }) {
            guard revision > (current.items[index].sourceRevision ?? 0) else {
                return current.items[index]
            }
            // Filing may have renamed this entry while an editor snapshot was
            // in flight. Source writes own files, not the library name.
            current.items[index].project = GopherForgeProject(
                name: current.items[index].project.name,
                files: project.files,
                entryFile: project.entryFile,
                provenance: project.provenance
            )
            current.items[index].sourceRevision = revision
            current.items[index].lastOpenedAt = Date()
        } else {
            current.items.append(
                ProjectLibraryItem(
                    id: id,
                    project: project,
                    lastOpenedAt: Date(),
                    sourceRevision: revision
                )
            )
        }

        current.items.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        try persist(current)
        return current.items.first { $0.id == id }!
    }

    /// A build describes the snapshot that ran. It must never write source.
    func recordBuild(id: UUID, result: ProjectBuildRecord) throws {
        var current = try state()
        guard let index = current.items.firstIndex(where: { $0.id == id }) else { return }
        current.items[index].lastBuild = result
        try persist(current)
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
