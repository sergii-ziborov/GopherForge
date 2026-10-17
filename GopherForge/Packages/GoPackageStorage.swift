import Foundation

/// Reclaim dependency source without removing the requirements that fetch it again.
enum GoPackageStorage {
    struct Summary: Equatable, Sendable {
        var projectCount = 0
        var fileCount = 0
        var byteCount: Int64 = 0

        mutating func include(_ other: Summary) {
            projectCount += other.projectCount
            fileCount += other.fileCount
            byteCount += other.byteCount
        }
    }

    private struct Plan {
        var paths: Set<String> = []
        var references: [GoModuleReference] = []
        var summary = Summary()
    }

    private static let exampleModules = Set(GoExampleLibrary.all.compactMap { example in
        GoModParser.parse(example.extraFiles["go.mod"] ?? GoLanguage.module(example.modulePath))?.modulePath
    })

    static func summary(in project: GopherForgeProject) -> Summary {
        plan(in: project).summary
    }

    static func clearingDownloadedPackages(
        from project: GopherForgeProject
    ) -> (project: GopherForgeProject, summary: Summary) {
        let plan = plan(in: project)
        guard !plan.paths.isEmpty else { return (project, plan.summary) }
        var files = project.files.filter { !plan.paths.contains($0.key) }
        let required = Set(project.module?.requirements.map(\.path) ?? [])
        // Older imported vendor trees can list a dependency only in modules.txt.
        // Preserve its pin before removing its source so the next build can fetch it.
        for reference in plan.references where !required.contains(reference.path) {
            files["go.mod"] = (files["go.mod"] ?? "").trimmingCharacters(in: .newlines)
                + "\n\nrequire \(reference.path) \(reference.version)\n"
        }
        if let text = files[GoVendorWriter.modulesFile] {
            let removed = Set(plan.references.map(\.path))
            var skipping = false
            let remaining = text.components(separatedBy: "\n").filter { line in
                if line.hasPrefix("# "), !line.hasPrefix("##") {
                    skipping = line.dropFirst(2).split(separator: " ").first.map { removed.contains(String($0)) } ?? false
                }
                return !skipping
            }.joined(separator: "\n")
            if remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                files.removeValue(forKey: GoVendorWriter.modulesFile)
            } else {
                files[GoVendorWriter.modulesFile] = remaining
            }
        }
        return (project.replacingFiles(files), plan.summary)
    }

    private static func plan(in project: GopherForgeProject) -> Plan {
        // Lesson workspaces never belong to this cleanup. The module fallback
        // protects examples saved before explicit example provenance was added.
        guard let module = project.module, module.modulePath != "lesson" else { return Plan() }
        if project.provenance?.source == .template,
           project.provenance?.reference?.hasPrefix("example:") == true
            || exampleModules.contains(module.modulePath) {
            return Plan()
        }
        let local = Set(module.replacements.filter(\.isLocal).map(\.path))
        let references = GoVendorWriter.installedModules(in: project.files)
            .filter { $0.isVendored && !local.contains($0.path) }
            .compactMap { GoModuleReference.validated(path: $0.path, version: $0.version) }
        let prefixes = references.map { "vendor/\($0.path)/" }
        var plan = Plan(references: references)
        for (path, text) in project.files where prefixes.contains(where: path.hasPrefix) {
            plan.paths.insert(path)
            plan.summary.fileCount += 1
            plan.summary.byteCount += Int64(text.utf8.count)
        }
        plan.summary.projectCount = plan.paths.isEmpty ? 0 : 1
        return plan
    }
}
