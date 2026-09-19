import Foundation

/// Installs a Go module into a project.
///
/// The sequence is fixed and every step has to pass before the next one runs:
/// resolve the version, fetch the archive, fetch what the checksum database
/// says the archive should hash to, hash it here, compare, and only then write
/// anything. A mismatch is a refusal, never a warning.
///
/// The network is used here and nowhere else in the product. What lands in the
/// project is source, so every build after this is offline again.
struct GoPackageInstaller: Sendable {
    enum InstallError: Error, Equatable {
        case invalidModulePath(String)
        case checksumMismatch(expected: String, actual: String)
        case noGoPackages(String)
    }

    struct Result: Equatable, Sendable {
        let reference: GoModuleReference
        let files: [String: String]
        /// Import paths the project can now use.
        let packages: [String]
        let vendoredFileCount: Int
        let verifiedHash: String
    }

    private let proxy: GoModuleProxyClient
    private let checksums: GoChecksumDatabase

    init(
        proxy: GoModuleProxyClient = GoModuleProxyClient(),
        checksums: GoChecksumDatabase = GoChecksumDatabase()
    ) {
        self.proxy = proxy
        self.checksums = checksums
    }

    func versions(of path: String) async throws -> [String] {
        try await proxy.versions(of: path)
    }

    func latestVersion(of path: String) async throws -> String {
        try await proxy.latestVersion(of: path)
    }

    /// Downloads, verifies and vendors, returning the project's new files.
    func install(
        path: String,
        version: String,
        into files: [String: String]
    ) async throws -> Result {
        guard let reference = GoModuleReference.validated(path: path, version: version) else {
            throw InstallError.invalidModulePath("\(path)@\(version)")
        }

        let data = try await proxy.archive(for: reference)
        let archive = try GoModuleArchive(data: data, reference: reference)

        // Verify before anything is written. The order matters: a project must
        // never contain bytes that failed this check, not even briefly.
        let record = try await checksums.record(for: reference)
        let actual = try archive.hash()
        guard actual == record.moduleHash else {
            throw InstallError.checksumMismatch(expected: record.moduleHash, actual: actual)
        }

        let vendored = archive.vendoredFiles()
        let packages = Self.packages(in: vendored, modulePath: reference.path)
        guard !packages.isEmpty else { throw InstallError.noGoPackages(reference.id) }

        let updated = GoVendorWriter.apply(
            installation: .init(reference: reference, packages: packages),
            vendoredFiles: vendored,
            goSumLines: GoChecksumDatabase.goSumLines(for: reference, record: record),
            to: files
        )

        return Result(
            reference: reference,
            files: updated,
            packages: packages,
            vendoredFileCount: vendored.count,
            verifiedHash: actual
        )
    }

    /// Import paths a vendored module offers: every directory holding a `.go`
    /// file, named from the module root.
    static func packages(in vendoredFiles: [String: String], modulePath: String) -> [String] {
        var paths: Set<String> = []
        for relative in vendoredFiles.keys where relative.hasSuffix(".go") {
            let directory = relative.split(separator: "/").dropLast().joined(separator: "/")
            paths.insert(directory.isEmpty ? modulePath : "\(modulePath)/\(directory)")
        }
        return paths.sorted()
    }
}
