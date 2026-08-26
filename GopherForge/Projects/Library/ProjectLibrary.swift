import Foundation

/// The recent-projects list, persisted as one small JSON document.
///
/// An actor because the workspace, the importer and the share queue all record
/// into it, and the list must never be half-written.
actor ProjectLibrary {
    private struct State: Codable {
        var items: [ProjectLibraryItem]
    }

    private let storageURL: URL
    private var cachedState: State?
    private let maximumRecentProjects = 10

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
        if current.items.count > maximumRecentProjects {
            current.items = Array(current.items.prefix(maximumRecentProjects))
        }
        try persist(current)
        return current.items
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
