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
        let all = Set(
            (existing + "\n" + lines)
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
        // Deterministic order so a re-install produces an identical file.
        return all.sorted().joined(separator: "\n") + "\n"
    }

    /// A module the project has required or already vendored.
    ///
    /// The navigator shows these as packages. Expanding `vendor/` into a file
    /// tree is how gin becomes two hundred rows nobody asked to edit.
    struct InstalledModule: Equatable, Identifiable, Sendable {
        let path: String
        let version: String
        let isIndirect: Bool
        /// True when the module's source is under `vendor/`.
        let isVendored: Bool

        var id: String { path }

        var displayName: String {
            path.split(separator: "/").last.map(String.init) ?? path
        }
    }

    /// Paths the file tree should not list. A vendored module is a package,
    /// not a folder of source someone is expected to page through.
    static func isVendoredPath(_ path: String) -> Bool {
        path == vendorDirectory || path.hasPrefix(vendorDirectory + "/")
    }

    /// Required and vendored modules, direct ones first.
    ///
    /// `go.mod` is the source of truth for what the owner added. `modules.txt`
    /// fills in a module that is on disk but missing from the require block,
    /// so a hand-copied vendor directory still appears as a package.
    static func installedModules(in files: [String: String]) -> [InstalledModule] {
        let requirements = GoModParser.parse(files["go.mod"] ?? "")?.requirements ?? []
        var listed: [InstalledModule] = requirements.map { requirement in
            InstalledModule(
                path: requirement.path,
                version: requirement.version,
                isIndirect: requirement.isIndirect,
                isVendored: files.keys.contains {
                    $0.hasPrefix("\(vendorDirectory)/\(requirement.path)/")
                }
            )
        }
        let listedPaths = Set(listed.map(\.path))
        for extra in modulesListed(in: files[modulesFile] ?? "") where !listedPaths.contains(extra.path) {
            listed.append(extra)
        }
        return listed.sorted {
            if $0.isIndirect != $1.isIndirect { return !$0.isIndirect }
            return $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    /// Drops the module's `vendor/` tree, its `require` line and its `go.sum`
    /// entries, then rebuilds `modules.txt` from what remains.
    static func remove(modulePath: String, from files: [String: String]) -> [String: String] {
        var result = files
        let prefix = "\(vendorDirectory)/\(modulePath)/"
        for path in result.keys where path.hasPrefix(prefix) {
            result.removeValue(forKey: path)
        }

        result["go.mod"] = removingRequire(modulePath, from: result["go.mod"] ?? "")
        if let sum = result["go.sum"] {
            let trimmed = removingGoSum(modulePath, from: sum)
            if trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.removeValue(forKey: "go.sum")
            } else {
                result["go.sum"] = trimmed
            }
        }

        let modules = modulesText(for: result)
        if modules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.removeValue(forKey: modulesFile)
        } else {
            result[modulesFile] = modules
        }
        return result
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

    /// `# module version` lines, which is what `go mod vendor` writes.
    static func modulesListed(in modulesText: String) -> [InstalledModule] {
        var listed: [InstalledModule] = []
        for line in modulesText.components(separatedBy: "\n") {
            guard line.hasPrefix("# "), !line.hasPrefix("##") else { continue }
            let fields = line.dropFirst(2).split(separator: " ").map(String.init)
            guard let path = fields.first, !path.isEmpty else { continue }
            listed.append(
                InstalledModule(
                    path: path,
                    version: fields.dropFirst().first ?? "",
                    isIndirect: false,
                    isVendored: true
                )
            )
        }
        return listed
    }

    static func removingRequire(_ modulePath: String, from source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        lines.removeAll { requireLineModulePath($0) == modulePath }
        return collapseEmptyRequireBlocks(lines)
    }

    /// A `require (` whose last member was just deleted is leftover syntax,
    /// not a module, and must not stay in `go.mod`.
    static func collapseEmptyRequireBlocks(_ lines: [String]) -> String {
        var result: [String] = []
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "require (" {
                var cursor = index + 1
                var inner: [String] = []
                var foundClose = false
                while cursor < lines.count {
                    if lines[cursor].trimmingCharacters(in: .whitespaces) == ")" {
                        foundClose = true
                        break
                    }
                    inner.append(lines[cursor])
                    cursor += 1
                }
                let hasRequirement = inner.contains { requireLineModulePath($0) != nil }
                if foundClose, !hasRequirement {
                    index = cursor + 1
                    continue
                }
            }
            result.append(lines[index])
            index += 1
        }
        while result.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            result.removeLast()
        }
        return result.isEmpty ? "" : result.joined(separator: "\n") + "\n"
    }

    static func removingGoSum(_ modulePath: String, from existing: String) -> String {
        let kept = existing
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty else { return false }
                return line.split(separator: " ").first.map(String.init) != modulePath
            }
        return kept.isEmpty ? "" : kept.sorted().joined(separator: "\n") + "\n"
    }
}
