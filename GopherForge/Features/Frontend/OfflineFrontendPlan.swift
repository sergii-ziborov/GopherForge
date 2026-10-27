import CryptoKit
import Foundation

/// A browser build recipe, never executable project configuration.
struct OfflineFrontendRecipe: Codable, Equatable, Sendable {
    var entry: String
    var html: String
    var output: String
    var minify: Bool = true

    private enum CodingKeys: String, CodingKey { case entry, html, output, minify }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        entry = try values.decode(String.self, forKey: .entry)
        html = try values.decode(String.self, forKey: .html)
        output = try values.decode(String.self, forKey: .output)
        minify = try values.decodeIfPresent(Bool.self, forKey: .minify) ?? true
    }

    static let path = "gopherforge.frontend.json"
    static let lockPath = "gopherforge.frontend.lock.json"
}

struct OfflineFrontendPackage: Codable, Sendable {
    let name: String
    let version: String
    let integrity: String
    let dependencies: [String: String]
    let files: [String: String]
}

struct OfflineFrontendCatalog: Codable, Sendable {
    let format: Int
    let packages: [OfflineFrontendPackage]

    func resolve(_ requested: [String: String]) throws -> [OfflineFrontendPackage] {
        var resolved: [String: OfflineFrontendPackage] = [:]
        var pending = requested.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
        while !pending.isEmpty {
            let (name, range) = pending.removeFirst()
            guard let package = packages.first(where: { $0.name == name }),
                  Self.matches(package.version, range: range) else {
                throw OfflineFrontendError.message("\(name)@\(range) is not in the bundled offline catalog. No download was attempted.")
            }
            if resolved[name] != nil { continue }
            resolved[name] = package
            for (dependency, constraint) in package.dependencies {
                guard let installed = resolved[dependency] else { pending.append((dependency, constraint)); continue }
                guard Self.matches(installed.version, range: constraint) else {
                    throw OfflineFrontendError.message("The bundled versions do not satisfy \(dependency)@\(constraint).")
                }
            }
        }
        return resolved.values.sorted { $0.name < $1.name }
    }

    /// Deliberately bounded ranges for a fixed offline catalog, not npm's solver.
    static func matches(_ version: String, range: String) -> Bool {
        let range = range.trimmingCharacters(in: .whitespacesAndNewlines)
        func components(_ text: String) -> [Int]? {
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 3 else { return nil }
            var numbers: [Int] = []
            for part in parts {
                guard !part.isEmpty, part.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                      part.count == 1 || part.first != "0", let number = Int(part) else { return nil }
                numbers.append(number)
            }
            return numbers
        }
        guard let actual = components(version) else { return false }
        if range == "*" || range == version { return true }
        guard let prefix = range.first, prefix == "^" || prefix == "~" else { return false }
        guard let target = components(String(range.dropFirst())) else { return false }
        let atLeast = !actual.lexicographicallyPrecedes(target)
        if prefix == "~" { return atLeast && actual[0] == target[0] && actual[1] == target[1] }
        if target[0] != 0 { return atLeast && actual[0] == target[0] }
        if target[1] != 0 { return atLeast && actual[0] == 0 && actual[1] == target[1] }
        return actual == target
    }
}

enum OfflineFrontendError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

struct OfflineFrontendPlan: Sendable {
    let recipe: OfflineFrontendRecipe
    let packages: [OfflineFrontendPackage]
    let lock: String

    init(files: [String: String], catalog: OfflineFrontendCatalog) throws {
        guard let manifest = files["package.json"], manifest.utf8.count <= 256 * 1024,
              let data = manifest.data(using: .utf8),
              let package = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OfflineFrontendError.message("This project needs package.json and gopherforge.frontend.json for an offline browser build.")
        }
        guard let json = files[OfflineFrontendRecipe.path]?.data(using: .utf8), json.count <= 16 * 1024 else {
            throw OfflineFrontendError.message("Add gopherforge.frontend.json with entry, html, output and minify. Offline mode does not execute Vite/Node configuration or package scripts.")
        }
        let recipe = try JSONDecoder().decode(OfflineFrontendRecipe.self, from: json)
        self.recipe = recipe
        let reserved = ["node_modules", ".git", "vendor"]
        for path in [recipe.entry, recipe.html, recipe.output] {
            guard Self.validPath(path), !reserved.contains(path.split(separator: "/").first.map(String.init) ?? "") else {
                throw OfflineFrontendError.message("Frontend paths must stay inside the project, outside vendor, node_modules and .git.")
            }
        }
        guard recipe.output.hasSuffix("/dist") || recipe.output == "dist",
              !recipe.entry.hasPrefix(recipe.output + "/"), !recipe.html.hasPrefix(recipe.output + "/") else {
            throw OfflineFrontendError.message("Use a separate dist output directory; source files must be outside it.")
        }
        guard files[recipe.entry] != nil, files[recipe.html] != nil else {
            throw OfflineFrontendError.message("The frontend entry or HTML template is missing.")
        }
        if files.keys.contains(where: { $0.hasPrefix(recipe.output + "/") }), files[recipe.output + "/.gopherforge-build.json"] == nil {
            throw OfflineFrontendError.message("The output directory contains files not created by this builder. Choose an empty dist directory to preserve them.")
        }
        guard files[recipe.html]!.contains("<!-- gopherforge:assets -->") else {
            throw OfflineFrontendError.message("The HTML template needs <!-- gopherforge:assets --> for the generated script and stylesheet.")
        }
        var requested: [String: String] = [:]
        for key in ["dependencies", "devDependencies"] {
            if let value = package[key] {
                guard let dependencies = value as? [String: String] else { throw OfflineFrontendError.message("\(key) must map package names to version strings.") }
                requested.merge(dependencies) { _, next in next }
            }
        }
        packages = try catalog.resolve(requested)
        let lockObject: [String: Any] = ["format": 1, "mode": "gopherforge-offline-frontend", "packages": packages.map { ["name": $0.name, "version": $0.version, "integrity": $0.integrity] }]
        lock = String(decoding: try JSONSerialization.data(withJSONObject: lockObject, options: [.sortedKeys, .prettyPrinted]), as: UTF8.self) + "\n"
    }

    static func validPath(_ path: String) -> Bool {
        !path.isEmpty && !path.contains("\\") && !path.contains("\0") && !path.hasPrefix("/")
            && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    static func digest(files: [String: String], output: String) -> String {
        var hash = SHA256()
        for (path, text) in files.sorted(by: { $0.key < $1.key }) where !path.hasPrefix(output + "/") && path != OfflineFrontendRecipe.lockPath {
            hash.update(data: Data("\(path.utf8.count):\(path)\(text.utf8.count):\(text)".utf8))
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func previewReady(files: [String: String]) -> Bool {
        guard let data = files[OfflineFrontendRecipe.path]?.data(using: .utf8),
              let recipe = try? JSONDecoder().decode(OfflineFrontendRecipe.self, from: data), validPath(recipe.output),
              files[recipe.output + "/index.html"] != nil,
              files[recipe.output + "/assets/app.js"] != nil,
              let stamp = files[recipe.output + "/.gopherforge-build.json"] else { return false }
        return stamp == digest(files: files, output: recipe.output)
    }
}
