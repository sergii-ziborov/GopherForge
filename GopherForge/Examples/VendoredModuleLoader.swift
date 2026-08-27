import Foundation

/// Loads a module that ships inside the app, ready to be vendored into a
/// project.
///
/// An example project that uses a real dependency is worth more than one that
/// only uses the standard library — it shows the shape of `vendor/`, the
/// `require` line and the `go.sum` entry, and it works with no network at all.
/// The source is a bundled resource rather than a Swift string literal: two
/// hundred kilobytes of Go embedded in Swift would be unreadable, slow to
/// compile, and impossible to update by re-downloading.
struct VendoredModuleLoader {
    /// A module the app ships, with the checksums Go recorded for it.
    struct Bundled: Sendable, Equatable {
        let reference: GoModuleReference
        /// The `h1:` hashes from sum.golang.org, written verbatim into the
        /// project's `go.sum` so the record travels with the code.
        let moduleHash: String
        let goModHash: String

        var goSumLines: String {
            GoChecksumDatabase.goSumLines(
                for: reference,
                record: .init(moduleHash: moduleHash, goModHash: goModHash)
            )
        }
    }

    static let goCmp = Bundled(
        reference: GoModuleReference(path: "github.com/google/go-cmp", version: "v0.6.0"),
        moduleHash: "h1:ofyhxvXcZhMsU5ulbFiLKl/XBFqE1GSq7atu8tAmTRI=",
        goModHash: "h1:17dUlkBOakJ0+DkrSSNjCkIjxS6bF9zb3elmeNGIjoY="
    )

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// Every file of the module, keyed by its `vendor/…` path in a project.
    ///
    /// Empty when the resource is missing, which is a build-configuration
    /// problem rather than a user's: an example that needs it says so instead
    /// of shipping a project that cannot compile.
    func vendorFiles(for module: Bundled) -> [String: String] {
        guard let root = bundle.resourceURL?
            .appendingPathComponent("VendoredModules", isDirectory: true)
            .appendingPathComponent(module.reference.path, isDirectory: true),
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return [:]
        }

        let prefix = "\(GoVendorWriter.vendorDirectory)/\(module.reference.path)/"
        var files: [String: String] = [:]
        for case let url as URL in enumerator {
            guard url.hasDirectoryPath == false,
                  let relative = Self.relativePath(of: url, under: root),
                  let contents = try? String(contentsOf: url, encoding: .utf8)
            else {
                continue
            }
            files[prefix + relative] = contents
        }
        return files
    }

    /// Adds the module to a project: its source under `vendor/`, a `require`
    /// line, the `go.sum` entries and a rebuilt `vendor/modules.txt`.
    func vendoring(_ module: Bundled, into files: [String: String]) -> [String: String] {
        let vendored = vendorFiles(for: module)
        guard !vendored.isEmpty else { return files }

        var result = files
        for (path, contents) in vendored { result[path] = contents }
        result["go.mod"] = GoVendorWriter.updatedGoMod(
            result["go.mod"] ?? "",
            adding: module.reference
        )
        result["go.sum"] = GoVendorWriter.appendGoSum(module.goSumLines, to: result["go.sum"] ?? "")
        result[GoVendorWriter.modulesFile] = GoVendorWriter.modulesText(for: result)
        return result
    }

    static func relativePath(of url: URL, under root: URL) -> String? {
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.count > rootComponents.count,
              Array(components.prefix(rootComponents.count)) == rootComponents
        else {
            return nil
        }
        return components.dropFirst(rootComponents.count).joined(separator: "/")
    }
}
