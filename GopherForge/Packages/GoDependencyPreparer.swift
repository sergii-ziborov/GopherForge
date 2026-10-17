import Foundation

/// Which published module satisfies an import, using the versions in `go.mod`.
///
/// The module graph is already solved in that file: every requirement, direct
/// or indirect, names the version this project builds with. Matching an import
/// to the longest requirement path is the same choice `go` makes.
enum GoRequirementMatch {
    struct Resolved: Equatable, Sendable {
        let path: String
        let version: String
    }

    enum MatchError: Error, Equatable {
        /// The import is a package of this module, and the file is simply not here.
        case missingFromProject(importPath: String)
        /// Nothing in `go.mod` provides this import.
        case notRequired(importPath: String)
        /// `replace` points at a directory on the author's machine.
        case localReplacement(module: String, path: String)
    }

    static func resolve(importPath: String, module: GoModule) -> Result<Resolved, MatchError> {
        if importPath == module.modulePath || importPath.hasPrefix(module.modulePath + "/") {
            return .failure(.missingFromProject(importPath: importPath))
        }
        guard let requirement = module.requirements
            .filter({ importPath == $0.path || importPath.hasPrefix($0.path + "/") })
            .max(by: { $0.path.count < $1.path.count })
        else {
            return .failure(.notRequired(importPath: importPath))
        }

        if let replacement = module.replacements.first(where: { $0.path == requirement.path }) {
            if replacement.isLocal {
                return .failure(.localReplacement(module: requirement.path, path: replacement.replacement))
            }
            let fields = replacement.replacement.split(separator: " ").map(String.init)
            guard let path = fields.first, !path.isEmpty else {
                return .failure(.localReplacement(module: requirement.path, path: replacement.replacement))
            }
            let version = fields.count >= 2 ? fields[1] : requirement.version
            return .success(Resolved(path: path, version: version))
        }

        return .success(Resolved(path: requirement.path, version: requirement.version))
    }
}

/// Downloads the modules a build is missing, then stops.
///
/// The compiler itself stays offline. This runs once, before planning is
/// handed to it, and only for an import `go.mod` already names. What it writes
/// is vendored source, so the next build does not ask the network again.
/// One module the download window tried and could not keep.
struct PackageDownloadProblem: Equatable, Identifiable, Sendable {
    enum Reason: Equatable, Sendable {
        /// The bytes never arrived: the network, the proxy, or a check failed.
        case notLoaded
        /// The phone or the download limit refused the size.
        case noSpace
        /// The version in go.mod is not one this app can install.
        case unsupportedVersion
    }

    let module: String
    let reason: Reason
    let detail: String

    var id: String { module }

    var outputLine: String {
        switch reason {
        case .notLoaded:
            "\(module) was not loaded. \(detail)"
        case .noSpace:
            "\(module) was not loaded: there isn't enough space. \(detail)"
        case .unsupportedVersion:
            "\(module) was not loaded: this version isn't supported. \(detail)"
        }
    }
}

struct GoDependencyPreparer {
    struct Prepared: Equatable, Sendable {
        let files: [String: String]
        let installed: [String]
        var problems: [PackageDownloadProblem] = []
    }

    enum Failure: LocalizedError, Equatable {
        case missingFromProject(importPath: String, files: [String: String])
        case localReplacement(module: String, path: String, files: [String: String])
        case repeated(module: String, files: [String: String])
        case tooManyModules(Int, files: [String: String])
        case installFailed(module: String, detail: String, files: [String: String])

        var files: [String: String] {
            switch self {
            case let .missingFromProject(_, files),
                 let .localReplacement(_, _, files),
                 let .repeated(_, files),
                 let .tooManyModules(_, files),
                 let .installFailed(_, _, files):
                files
            }
        }

        var errorDescription: String? { detail }

        var detail: String {
            switch self {
            case let .missingFromProject(importPath, _):
                "\(importPath) belongs to this module, but those source files are not in the project."
            case let .localReplacement(module, path, _):
                "\(module) is replaced with \(path), which is a folder on another machine. "
                    + "This project cannot download that."
            case let .repeated(module, _):
                "\(module) was added, but the import still does not resolve. "
                    + "The module does not contain that package."
            case let .tooManyModules(limit, _):
                "This build needs more than \(limit) modules. The rest were left unvendored."
            case let .installFailed(module, detail, _):
                "Could not add \(module). \(detail)"
            }
        }
    }

    var maximumModules = 80
    /// `skipping` is the set of module paths that already failed. The next
    /// import should be one that is not in that set, so one failure does not
    /// hide the rest.
    var planError: (_ files: [String: String], _ skipping: Set<String>) async -> GoPackageGraph.GraphError?
    /// Module path, version, the import that asked for it, and the project files.
    var install: (String, String, String, [String: String]) async throws -> [String: String]
    var shouldStop: () -> Bool = { false }

    @MainActor
    func prepare(files: [String: String]) async throws -> Prepared {
        var files = files
        var installed: [String] = []
        var problems: [PackageDownloadProblem] = []
        var failed: Set<String> = []
        var seen: Set<String> = []

        for _ in 0..<maximumModules {
            if shouldStop() {
                return Prepared(files: files, installed: installed, problems: problems)
            }
            guard let error = await planError(files, failed),
                  case let .unresolvedImport(importPath, _) = error
            else {
                return Prepared(files: files, installed: installed, problems: problems)
            }
            guard let module = GoModParser.parse(files["go.mod"] ?? "") else {
                return Prepared(files: files, installed: installed, problems: problems)
            }

            let resolved: GoRequirementMatch.Resolved
            switch GoRequirementMatch.resolve(importPath: importPath, module: module) {
            case let .success(match):
                resolved = match
            case let .failure(.missingFromProject(importPath)):
                throw Failure.missingFromProject(importPath: importPath, files: files)
            case .failure(.notRequired):
                return Prepared(files: files, installed: installed, problems: problems)
            case let .failure(.localReplacement(module, path)):
                throw Failure.localReplacement(module: module, path: path, files: files)
            }

            if failed.contains(resolved.path) {
                return Prepared(files: files, installed: installed, problems: problems)
            }
            guard seen.insert(resolved.path).inserted else {
                problems.append(
                    PackageDownloadProblem(
                        module: resolved.path,
                        reason: .notLoaded,
                        detail: "\(resolved.path) was added, but the import still does not resolve. "
                            + "The module does not contain that package."
                    )
                )
                failed.insert(resolved.path)
                continue
            }

            do {
                files = try await install(resolved.path, resolved.version, importPath, files)
                installed.append(resolved.path)
            } catch is CancellationError {
                if shouldStop() {
                    return Prepared(files: files, installed: installed, problems: problems)
                }
                problems.append(PackageDownloadProblem(
                    module: resolved.path,
                    reason: .notLoaded,
                    detail: "The download of this package stopped. Retry loads it again."
                ))
                failed.insert(resolved.path)
            } catch {
                let problem = Self.problem(for: error, module: "\(resolved.path)@\(resolved.version)")
                problems.append(problem)
                failed.insert(resolved.path)
            }
        }

        throw Failure.tooManyModules(maximumModules, files: files)
    }

    static func problem(for error: any Error, module: String) -> PackageDownloadProblem {
        PackageDownloadProblem(module: module, reason: reason(for: error), detail: describe(error, path: module))
    }

    static func reason(for error: any Error) -> PackageDownloadProblem.Reason {
        if isOutOfSpace(error) { return .noSpace }
        if isUnsupportedVersion(error) { return .unsupportedVersion }
        return .notLoaded
    }

    /// A full phone, and nothing else. A module that is larger than the
    /// download ceiling is still a package this app refused, which is a
    /// different fact from the device having nowhere to write.
    private static func isOutOfSpace(_ error: any Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           CocoaError.Code(rawValue: nsError.code) == .fileWriteOutOfSpace {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == 28 { return true }
        let text = nsError.localizedDescription.lowercased()
        return text.contains("no space") || text.contains("not enough space")
    }

    private static func isUnsupportedVersion(_ error: any Error) -> Bool {
        switch error {
        case GoPackageInstaller.InstallError.invalidModulePath:
            return true
        default:
            return false
        }
    }

    /// The same sentences the package installer shows, so a failed download
    /// reads the same whether the user added the module or the build did.
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
        case let GoModuleProxyClient.ProxyError.badStatus(status, _):
            "The Go module proxy returned HTTP \(status) for \(path). Use Retry, or check the module version."
        case GoModuleProxyClient.ProxyError.malformedResponse:
            "The Go module proxy returned an unreadable version response. Use Retry."
        case let GoModuleProxyClient.ProxyError.tooLarge(bytes):
            downloadTooLarge(bytes)
        case let GoHTTPTransportError.tooLarge(bytes, _):
            downloadTooLarge(bytes)
        case let GoModuleArchive.ArchiveError.tooLarge(bytes):
            unpackedTooLarge(bytes)
        case GoChecksumDatabase.ChecksumError.notFound:
            "\(path) is not in the Go checksum database, so it cannot be verified."
        case let GoChecksumDatabase.ChecksumError.badStatus(status):
            "The Go checksum service returned HTTP \(status). Nothing was installed. Use Retry."
        case GoChecksumDatabase.ChecksumError.noHashInResponse:
            "The Go checksum service did not return checksums for this module version. Nothing was installed."
        case GoChecksumDatabase.ChecksumError.mismatch:
            "The download did not match the official checksum database. Nothing was installed."
        case GoModuleArchive.ArchiveError.unreadable:
            "The downloaded module archive is unreadable or damaged. Use Retry to download it again."
        case let GoModuleArchive.ArchiveError.tooManyFiles(count):
            "The module contains \(count) files. This app keeps at most \(GoModuleArchive.maximumFiles) files per module."
        case GoModuleArchive.ArchiveError.emptyModule:
            "The downloaded module archive contains no files. Nothing was installed."
        case let GoModuleArchive.ArchiveError.entryOutsideModule(name):
            "The archive contains a file outside the module: \(name). Nothing was installed."
        case let error as URLError:
            describeNetworkError(error)
        default:
            if isOutOfSpace(error) {
                "The phone could not save the package. Free some space and use Retry."
            } else {
                "The package could not be installed. \(error.localizedDescription)"
            }
        }
    }

    private static func describeNetworkError(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            "GopherForge cannot access the internet. Check Wi-Fi or cellular data for the app, then use Retry."
        case .dataNotAllowed:
            "Cellular data is unavailable for this request. Allow cellular data for GopherForge in Settings or connect to Wi-Fi, then use Retry."
        case .timedOut:
            "The package service took too long to respond. Use Retry."
        case .networkConnectionLost:
            "The package connection was interrupted. Use Retry."
        case .cancelled:
            "The package download stopped. Use Retry."
        default:
            "The package request failed: \(error.localizedDescription)"
        }
    }

    private static func downloadTooLarge(_ bytes: Int) -> String {
        "The download is \(megabytes(bytes)) MB. This app downloads at most "
            + "\(megabytes(GoModuleProxyClient.maximumArchiveBytes)) MB of one package."
    }

    private static func unpackedTooLarge(_ bytes: Int) -> String {
        "Unpacked, that module is \(megabytes(bytes)) MB. This app keeps at most "
            + "\(megabytes(GoModuleArchive.maximumUncompressedBytes)) MB of one package."
    }

    private static func megabytes(_ bytes: Int) -> Int {
        max(1, (bytes + 1_048_575) / 1_048_576)
    }
}
