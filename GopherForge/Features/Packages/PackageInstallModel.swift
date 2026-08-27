import Foundation
import Observation

/// Drives the package browser: what was typed, what was found, what happened.
@MainActor
@Observable
final class PackageInstallModel {
    enum Phase: Equatable {
        case idle
        case resolving
        case installing(String)
        case installed(String)
        case failed(String)
    }

    struct Resolved: Equatable {
        let path: String
        /// Newest first.
        let versions: [String]
        let insight: GoPackageInsight
    }

    var query = ""
    private(set) var phase: Phase = .idle
    private(set) var resolved: Resolved?
    private(set) var selectedVersion: String?
    private(set) var searchResults: [GoPackageSearchClient.Result] = []
    private(set) var isSearching = false

    private let installer: GoPackageInstaller
    private let insightClient: GoPackageInsightClient
    private let searchClient: GoPackageSearchClient
    private var searchTask: Task<Void, Never>?

    init(
        installer: GoPackageInstaller = GoPackageInstaller(),
        insightClient: GoPackageInsightClient = GoPackageInsightClient(),
        searchClient: GoPackageSearchClient = GoPackageSearchClient()
    ) {
        self.installer = installer
        self.insightClient = insightClient
        self.searchClient = searchClient
    }

    /// Searches after a pause, and abandons a search the typist has already
    /// moved past. Without both, every keystroke is a request and the answers
    /// arrive out of order.
    func searchAfterTyping() {
        searchTask?.cancel()
        let text = trimmedQuery
        guard text.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            isSearching = true
            let found = await searchClient.search(text)
            guard !Task.isCancelled else { return }
            searchResults = found
            isSearching = false
        }
    }

    var catalogMatches: [GoPackageCatalog.Entry] {
        GoPackageCatalog.filtered(by: query)
    }

    /// Search results that are not already in the local list, so the same
    /// module is not offered twice under two headings.
    var newSearchResults: [GoPackageSearchClient.Result] {
        let known = Set(catalogMatches.map(\.path))
        return searchResults.filter { !known.contains($0.path) }
    }

    /// True when the text is a module path worth asking the proxy about.
    var canResolveTypedPath: Bool {
        GoPackageCatalog.looksLikeModulePath(query) && resolved?.path != trimmedQuery
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBusy: Bool {
        switch phase {
        case .resolving, .installing: true
        default: false
        }
    }

    // MARK: - Actions

    func resolve(path: String) async {
        resolved = nil
        selectedVersion = nil
        phase = .resolving

        do {
            let versions = try await installer.versions(of: path)
            // A module with no tagged versions still has a latest pseudo-version.
            let available = versions.isEmpty ? [try await installer.latestVersion(of: path)] : versions
            let insight = await insightClient.insight(forModulePath: path)
            resolved = Resolved(path: path, versions: available, insight: insight)
            selectedVersion = GoSemanticVersion.newestStable(available) ?? available.first
            phase = .idle
        } catch {
            phase = .failed(Self.describe(error, path: path))
        }
    }

    func select(version: String) {
        selectedVersion = version
    }

    /// Installs into the given files and hands back the new ones, or nil if
    /// nothing was installed. The caller owns the project; this never mutates
    /// it behind their back.
    func install(into files: [String: String]) async -> [String: String]? {
        guard let resolved, let version = selectedVersion else { return nil }
        phase = .installing("\(resolved.path)@\(version)")

        do {
            let result = try await installer.install(
                path: resolved.path,
                version: version,
                into: files
            )
            phase = .installed(
                "\(result.reference.id) · \(result.vendoredFileCount) files · "
                    + "\(result.packages.count) package\(result.packages.count == 1 ? "" : "s")"
            )
            return result.files
        } catch {
            phase = .failed(Self.describe(error, path: resolved.path))
            return nil
        }
    }

    func clearStatus() {
        phase = .idle
    }

    /// Errors people can act on. A checksum mismatch in particular is stated
    /// as what it is rather than as a network problem.
    static func describe(_ error: any Error, path: String) -> String {
        switch error {
        case GoPackageInstaller.InstallError.checksumMismatch:
            "The download did not match the official checksum database. Nothing was installed."
        case GoPackageInstaller.InstallError.noGoPackages:
            "\(path) has no Go packages to vendor."
        case GoPackageInstaller.InstallError.invalidModulePath:
            "\(path) is not a module path the proxy can resolve."
        case GoModuleProxyClient.ProxyError.notFound:
            "The proxy has no module at \(path)."
        case let GoModuleProxyClient.ProxyError.tooLarge(bytes):
            "That module is \(bytes / 1_048_576) MB, larger than this app will vendor."
        case GoChecksumDatabase.ChecksumError.notFound:
            "\(path) is not in the Go checksum database, so it cannot be verified."
        case let GoModuleArchive.ArchiveError.entryOutsideModule(name):
            "The archive contains a file outside the module: \(name). Nothing was installed."
        default:
            "Could not reach the Go module proxy. Installing a package needs a network."
        }
    }
}
