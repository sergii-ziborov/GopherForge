import Foundation

/// Turning a pasted GitHub URL into an open project.
///
/// Parsing is separate from downloading so the field can say "that is not a
/// repository URL" while it is being typed, without asking the network
/// anything.
@MainActor
@Observable
final class GitHubImportModel {
    enum Phase: Equatable {
        case idle
        case downloading
        case failed(String)
    }

    var rawURL = ""
    private(set) var phase: Phase = .idle

    private let importer: GitHubRepositoryImporter

    init(importer: GitHubRepositoryImporter = GitHubRepositoryImporter()) {
        self.importer = importer
    }

    /// What the URL currently in the field points at, or nil while it is not
    /// yet a repository URL.
    var reference: GitHubRepositoryReference? {
        try? GitHubRepositoryReference.parse(rawURL)
    }

    var isDownloading: Bool { phase == .downloading }

    var canImport: Bool { reference != nil && !isDownloading }

    /// The problem with what has been typed so far, once enough has been typed
    /// to have a problem. An empty field is not an error, it is an empty field.
    var validationMessage: String? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, reference == nil else { return nil }
        do {
            _ = try GitHubRepositoryReference.parse(trimmed)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "That URL cannot be imported."
        }
    }

    func importRepository() async -> GopherForgeProject? {
        guard let reference else { return nil }
        phase = .downloading
        do {
            let project = try await importer.importRepository(reference)
            phase = .idle
            return project
        } catch {
            phase = .failed(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
            return nil
        }
    }

    func reset() {
        rawURL = ""
        phase = .idle
    }
}
