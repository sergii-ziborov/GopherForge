import Foundation

/// Compatible command spelling for a bounded educational frontend workflow.
/// No package lifecycle hooks, shell commands or native addons are executed.
enum OfflineFrontendCommand: Equatable {
    case install(frozen: Bool)
    case build(packageScript: Bool)
    case preview(packageScript: Bool)
    case packages
    case capabilities

    static func parse(_ fields: [String]) -> Self? {
        switch fields {
        case ["frontend", "install"], ["npm", "install"], ["npm", "install", "--offline"],
             ["bun", "install"], ["bun", "install", "--offline"]:
            return .install(frozen: false)
        case ["npm", "ci"], ["npm", "ci", "--offline"], ["bun", "install", "--frozen-lockfile"]:
            return .install(frozen: true)
        case ["frontend", "build"]: return .build(packageScript: false)
        case ["npm", "run", "build"], ["bun", "run", "build"]: return .build(packageScript: true)
        case ["frontend", "preview"]: return .preview(packageScript: false)
        case ["npm", "run", "preview"], ["bun", "run", "preview"]: return .preview(packageScript: true)
        case ["frontend", "packages"]: return .packages
        case ["npm", "--version"], ["bun", "--version"]: return .capabilities
        default: return nil
        }
    }

    static let capabilitiesText = """
    GopherForge offline frontend mode. npm/Bun command spelling is a compatibility
    subset, powered by the bundled esbuild WASI tool, not Node.js or the Bun runtime.
    Packages come only from the bundled catalog. No registry, network, plugins,
    lifecycle scripts, native addons, Vite dev server or arbitrary package scripts.
    Use frontend packages, frontend install, frontend build and frontend preview.
    """

    func validateScript(in files: [String: String]) throws {
        let name: String
        switch self {
        case .build(packageScript: true): name = "build"
        case .preview(packageScript: true): name = "preview"
        default: return
        }
        guard let data = files["package.json"]?.data(using: .utf8),
              let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = manifest["scripts"] as? [String: String],
              scripts[name] == "gopherforge \(name)" else {
            throw OfflineFrontendError.message("Offline mode accepts scripts.\(name) = gopherforge \(name). It does not execute arbitrary package scripts. Use frontend \(name) with a declarative gopherforge.frontend.json recipe.")
        }
    }
}
