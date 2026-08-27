import Foundation

/// Writes an installed module into a project the way `go mod vendor` would.
///
/// Vendoring rather than a module cache is the whole point: after this the
/// source is part of the project, so it travels with it, it is readable in the
/// editor, and every build afterwards is offline. The compiler never learns
/// that a network exists.
enum GoVendorWriter {
    static let vendorDirectory = "vendor"
    static let modulesFile = "vendor/modules.txt"

    struct Installation: Equatable, Sendable {
        let reference: GoModuleReference
        /// The packages this module contributes, as import paths.
        let packages: [String]
    }

    /// Returns the project's files with the module vendored in, `go.mod`
    /// updated, `go.sum` recorded and `vendor/modules.txt` rewritten.
    ///
    /// Pure: it takes files and returns files. Nothing here touches disk, which
    /// is what lets a test assert the whole result of an install.
    static func apply(
        installation: Installation,
        vendoredFiles: [String: String],
        goSumLines: String,
        to files: [String: String]
    ) -> [String: String] {
        var result = files

        // Replacing rather than merging: a re-install of a different version
        // must not leave the previous version's files behind.
        let prefix = "\(vendorDirectory)/\(installation.reference.path)/"
        for path in result.keys where path.hasPrefix(prefix) {
            result.removeValue(forKey: path)
        }
        for (relative, contents) in vendoredFiles {
            result[prefix + relative] = contents
        }

        result["go.mod"] = updatedGoMod(
            result["go.mod"] ?? "",
            adding: installation.reference
        )
        result["go.sum"] = appendGoSum(goSumLines, to: result["go.sum"] ?? "")
        result[modulesFile] = modulesText(for: result)
        return result
    }

    /// Adds or updates the module's `require` line, in place if it is already
    /// there so a version bump does not leave two lines for one module.
    static func updatedGoMod(_ source: String, adding reference: GoModuleReference) -> String {
        let requirement = "\t\(reference.path) \(reference.version)"
        var lines = source.isEmpty ? [] : source.components(separatedBy: "\n")

        if let index = lines.firstIndex(where: { requireLineModulePath($0) == reference.path }) {
            lines[index] = requirement
            return lines.joined(separator: "\n")
        }

        if let closing = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespaces) == ")" }) {
            lines.insert(requirement, at: closing)
            return lines.joined(separator: "\n")
        }

        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        lines.append(contentsOf: ["", "require (", requirement, ")", ""])
        return lines.joined(separator: "\n")
    }

    /// The module path on a `require` line, in either the block or the
    /// single-line form, or nil if this is not one.
    static func requireLineModulePath(_ line: String) -> String? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if let comment = trimmed.range(of: "//") {
            trimmed = String(trimmed[trimmed.startIndex..<comment.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }
        if trimmed.hasPrefix("require ") { trimmed = String(trimmed.dropFirst("require ".count)) }
        let fields = trimmed.split(separator: " ").map(String.init)
        guard fields.count == 2, fields[1].hasPrefix("v") else { return nil }
        return fields[0]
    }

    /// `go.sum` lines are unique and sorted, and adding one twice is the most
    /// common way to corrupt the file by hand.
    static func appendGoSum(_ lines: String, to existing: String) -> String {
        var all = Set(
            (existing + "\n" + lines)
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
        // Deterministic order so a re-install produces an identical file.
        return all.sorted().joined(separator: "\n") + "\n"
    }

    /// `vendor/modules.txt` rebuilt from what is actually in `vendor/`, so it
    /// can never claim a module the directory does not have.
    static func modulesText(for files: [String: String]) -> String {
        var packagesByModule: [String: Set<String>] = [:]
        var versions: [String: String] = [:]

        for line in (files["go.mod"] ?? "").components(separatedBy: "\n") {
            guard let path = requireLineModulePath(line) else { continue }
            let fields = line.trimmingCharacters(in: .whitespaces).split(separator: " ")
            versions[path] = String(fields[fields.count - 1])
        }

        for path in files.keys where path.hasPrefix("\(vendorDirectory)/") && path.hasSuffix(".go") {
            let importPath = path
                .dropFirst(vendorDirectory.count + 1)
                .split(separator: "/")
                .dropLast()
                .joined(separator: "/")
            guard let module = versions.keys
                .filter({ importPath == $0 || importPath.hasPrefix($0 + "/") })
                .max(by: { $0.count < $1.count })
            else {
                continue
            }
            packagesByModule[module, default: []].insert(importPath)
        }

        var lines: [String] = []
        for module in packagesByModule.keys.sorted() {
            lines.append("# \(module) \(versions[module] ?? "")")
            lines.append("## explicit")
            lines.append(contentsOf: packagesByModule[module]?.sorted() ?? [])
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }
}
