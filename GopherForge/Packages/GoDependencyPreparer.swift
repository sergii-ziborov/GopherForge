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
struct GoDependencyPreparer {
    struct Prepared: Equatable, Sendable {
        let files: [String: String]
        let installed: [String]
    }

    enum Failure: Error, Equatable {
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
    var planError: ([String: String]) -> GoPackageGraph.GraphError?
    var install: (String, String, [String: String]) async throws -> [String: String]

    @MainActor
    func prepare(files: [String: String]) async throws -> Prepared {
        var files = files
        var installed: [String] = []
        var seen: Set<String> = []

        for _ in 0..<maximumModules {
            guard let error = planError(files),
                  case let .unresolvedImport(importPath, _) = error
            else {
                return Prepared(files: files, installed: installed)
            }
            guard let module = GoModParser.parse(files["go.mod"] ?? "") else {
                return Prepared(files: files, installed: installed)
            }

            let resolved: GoRequirementMatch.Resolved
            switch GoRequirementMatch.resolve(importPath: importPath, module: module) {
            case let .success(match):
                resolved = match
            case let .failure(.missingFromProject(importPath)):
                throw Failure.missingFromProject(importPath: importPath, files: files)
            case .failure(.notRequired):
                return Prepared(files: files, installed: installed)
            case let .failure(.localReplacement(module, path)):
                throw Failure.localReplacement(module: module, path: path, files: files)
            }

            guard seen.insert(resolved.path).inserted else {
                throw Failure.repeated(module: resolved.path, files: files)
            }

            do {
                files = try await install(resolved.path, resolved.version, files)
            } catch {
                throw Failure.installFailed(
                    module: "\(resolved.path)@\(resolved.version)",
                    detail: Self.describe(error, path: resolved.path),
                    files: files
                )
            }
            installed.append(resolved.path)
        }

        throw Failure.tooManyModules(maximumModules, files: files)
    }

    /// The same sentences the package installer shows, so a failed download
    /// reads the same whether the user added the module or the build did.
    private static func describe(_ error: any Error, path: String) -> String {
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
