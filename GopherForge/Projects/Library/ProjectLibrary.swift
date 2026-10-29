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
    private typealias State = ProjectLibraryDocument.State
    private var storageURL: URL
    private let deviceStorageURL: URL
    private var observedSources: [UUID: String] = [:]
    private var writerRevisions: [String: UInt64] = [:]
    private var requiresExistingDocument: Bool
    private var heldFolderScope: URL?
    private var restorationFailed = false

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

    init(storageURL: URL? = nil, deviceStorageURL: URL? = nil) {
        self.deviceStorageURL = deviceStorageURL ?? ProjectLibraryLocation.defaultFileURL()
        if let storageURL { self.storageURL = storageURL }
        else {
            do { self.storageURL = try ProjectLibraryLocation.restoredFileURL() }
            catch { self.storageURL = self.deviceStorageURL; restorationFailed = true }
        }
        let selectedURL = self.storageURL
        self.requiresExistingDocument = (storageURL == nil && ProjectLibraryLocation.usesChosenFolder)
            || FileManager.default.fileExists(atPath: selectedURL.path)
            || ProjectLibraryDocument.hasRecoveryFiles(beside: selectedURL)
    }

    /// Opens an existing library, or copies the current one into an empty
    /// folder. Keeps the security scope while that document remains active.
    func adoptFolder(_ folder: URL) throws -> [ProjectLibraryItem] {
        let access = folder.startAccessingSecurityScopedResource()
        var retained = false
        defer { if access && !retained { folder.stopAccessingSecurityScopedResource() } }
        let bookmark = try ProjectLibraryLocation.bookmark(for: folder)
        let destination = folder.appending(path: "recent-projects.json")
        let next = try prepareDestination(destination)
        ProjectLibraryLocation.remember(bookmark: bookmark)
        storageURL = destination
        restorationFailed = false
        requiresExistingDocument = true
        observedSources = Dictionary(uniqueKeysWithValues: next.items.map { ($0.id, ProjectLibraryDocument.sourceDigest($0.project.files)) })
        heldFolderScope?.stopAccessingSecurityScopedResource()
        heldFolderScope = access ? folder : nil
        retained = access
        return try items()
    }

    func useOnDeviceLibrary() throws -> [ProjectLibraryItem] {
        let destination = deviceStorageURL
        let next = try prepareDestination(destination)
        ProjectLibraryLocation.forgetChosenFolder()
        storageURL = destination
        restorationFailed = false
        requiresExistingDocument = true
        observedSources = Dictionary(uniqueKeysWithValues: next.items.map { ($0.id, ProjectLibraryDocument.sourceDigest($0.project.files)) })
        heldFolderScope?.stopAccessingSecurityScopedResource()
        heldFolderScope = nil
        return try items()
    }

    var storesInChosenFolder: Bool {
        ProjectLibraryLocation.usesChosenFolder
    }

    func items() throws -> [ProjectLibraryItem] {
        let items = try state().items.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        for item in items { observedSources[item.id] = ProjectLibraryDocument.sourceDigest(item.project.files) }
        return items
    }

    func project(id: UUID) throws -> ProjectLibraryItem? {
        let item = try state().items.first { $0.id == id }
        if let item { observedSources[id] = ProjectLibraryDocument.sourceDigest(item.project.files) }
        return item
    }

    func downloadedPackageStorage() throws -> GoPackageStorage.Summary {
        var summary = GoPackageStorage.Summary()
        for item in try state().items {
            summary.include(GoPackageStorage.summary(in: item.project))
        }
        return summary
    }

    struct PackageCleanup: Sendable {
        let items: [ProjectLibraryItem]
        let summary: GoPackageStorage.Summary
    }

    /// One atomic library write; older queued autosaves cannot restore packages.
    func clearDownloadedPackages() throws -> PackageCleanup {
        let cleanup: PackageCleanup = try edit { current in
            var summary = GoPackageStorage.Summary()
            for index in current.items.indices {
                let cleaned = GoPackageStorage.clearingDownloadedPackages(from: current.items[index].project)
                guard cleaned.summary.fileCount > 0 else { continue }
                current.items[index].project = cleaned.project
                current.items[index].sourceRevision = (current.items[index].sourceRevision ?? 0) &+ 1
                summary.include(cleaned.summary)
            }
            return PackageCleanup(items: current.items, summary: summary)
        }
        for item in cleanup.items { observedSources[item.id] = ProjectLibraryDocument.sourceDigest(item.project.files) }
        return cleanup
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

    /// Creates an independent project with the same source and filing.
    ///
    /// Build history and the star are intentionally not copied: both describe
    /// the original entry. Folder, tags and note are copied because they are
    /// still useful context for the new branch of work.
    func duplicate(id: UUID, named name: String) throws -> ProjectLibraryItem? {
        try edit { current in
            guard let original = current.items.first(where: { $0.id == id }) else { return nil }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let copy = ProjectLibraryItem(
                id: UUID(), project: original.project.renamed(to: trimmed), lastOpenedAt: Date(),
                sourceRevision: 0, folder: original.folder, tags: original.tags,
                isFavorite: false, summary: original.summary
            )
            current.items.append(copy)
            return copy
        }
    }

    /// Source writes are keyed by the library UUID, never by a mutable name.
    /// A delayed save from an older editor revision cannot replace newer code.
    @discardableResult
    func recordSource(
        id: UUID, revision: UInt64, project: GopherForgeProject,
        expectedBase: [String: String]? = nil, writerID: UUID? = nil
    ) throws -> ProjectLibraryItem {
        let base = expectedBase.map(ProjectLibraryDocument.sourceDigest) ?? observedSources[id]
        let incoming = ProjectLibraryDocument.sourceDigest(project.files)
        let writerKey = writerID.map { id.uuidString + $0.uuidString }
        let accepted = writerKey.flatMap { writerRevisions[$0] }
        let stored: ProjectLibraryItem = try edit { current in
            let index = current.items.firstIndex { $0.id == id }
            if let index, let accepted, revision < accepted { return current.items[index] }
            let existing = index.map { current.items[$0] }
            let currentDigest = existing.map { ProjectLibraryDocument.sourceDigest($0.project.files) }
            if let base, currentDigest != base, currentDigest != incoming {
                let pending = ProjectLibraryItem(
                    id: id, project: project, lastOpenedAt: Date(), sourceRevision: revision,
                    folder: existing?.folder, tags: existing?.tags, summary: existing?.summary
                )
                let copy = ProjectLibraryDocument.recoveryCopy(pending, reason: "conflict copy")
                current.items.append(copy)
                return copy
            }
            if let index {
                if writerID == nil, revision <= (current.items[index].sourceRevision ?? 0) { return current.items[index] }
                if currentDigest == incoming,
                   current.items[index].project.entryFile == project.entryFile,
                   current.items[index].project.provenance == project.provenance {
                    current.items[index].sourceRevision = max(revision, current.items[index].sourceRevision ?? 0)
                    return current.items[index]
                }
                current.items[index].project = GopherForgeProject(
                    name: current.items[index].project.name, files: project.files,
                    entryFile: project.entryFile, provenance: project.provenance
                )
                current.items[index].sourceRevision = max(revision, (current.items[index].sourceRevision ?? 0) &+ 1)
                current.items[index].lastOpenedAt = Date()
                return current.items[index]
            }
            let item = ProjectLibraryItem(id: id, project: project, lastOpenedAt: Date(), sourceRevision: revision)
            current.items.append(item)
            return item
        }
        observedSources[stored.id] = ProjectLibraryDocument.sourceDigest(stored.project.files)
        if let writerKey { writerRevisions[writerKey] = max(accepted ?? 0, revision) }
        return stored
    }

    /// Metadata updates reread under the same write lock; they never carry source.
    func recordBuild(id: UUID, result: ProjectBuildRecord) throws {
        try edit { current in
            guard let index = current.items.firstIndex(where: { $0.id == id }) else { return }
            current.items[index].lastBuild = result
        }
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
        try edit { current in
            guard let index = current.items.firstIndex(where: { $0.id == id }) else {
                return
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

        }
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
        try edit { current in current.items.removeAll { $0.id == id } }
        return try items()
    }

    // MARK: - Storage

    enum StorageError: LocalizedError, Equatable {
        case unsupportedSchema
        case verificationFailed
        case missingDocument
        case bookmarkUnavailable
        var errorDescription: String? {
            switch self {
            case .unsupportedSchema: "This library uses an unsupported format. It has not been changed."
            case .verificationFailed: "The new library could not be verified. The previous location is still active."
            case .missingDocument: "The library file was moved or removed. It has not been replaced with an empty library. Restore its location or export your current work."
            case .bookmarkUnavailable: "The selected Files or iCloud library could not be restored. Choose its folder again. The on-device library has not been substituted or changed."
            }
        }
    }

    private func readState(at url: URL) throws -> State { try ProjectLibraryDocument.read(url) }

    /// Existing libraries are opened, never replaced by the current library.
    /// A new destination receives a verified copy; the old document is kept.
    private func prepareDestination(_ destination: URL) throws -> State {
        if FileManager.default.fileExists(atPath: destination.path) {
            return try readState(at: destination)
        }
        let current = try state()
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Refuse a destination that appeared since the initial existence check.
        let encoded = try JSONEncoder.gopherForge.encode(current)
        try encoded.write(to: destination, options: .withoutOverwriting)
        guard try Data(contentsOf: destination) == encoded else { throw StorageError.verificationFailed }
        return try readState(at: destination)
    }

    private func state() throws -> State {
        guard !restorationFailed else { throw StorageError.bookmarkUnavailable }
        let state = try ProjectLibraryDocument.read(storageURL, requireExisting: requiresExistingDocument)
        if FileManager.default.fileExists(atPath: storageURL.path) { requiresExistingDocument = true }
        return state
    }

    private func edit<T>(_ update: (inout State) throws -> T) throws -> T {
        guard !restorationFailed else { throw StorageError.bookmarkUnavailable }
        let result = try ProjectLibraryDocument.modify(storageURL, requireExisting: requiresExistingDocument, update)
        if FileManager.default.fileExists(atPath: storageURL.path) { requiresExistingDocument = true }
        return result
    }
}
