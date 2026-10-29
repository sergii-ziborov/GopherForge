#if GOPHERFORGE_AUDIT_QA
import Foundation

/// Compiled only into the separately signed QA app. It never shares the main
/// app's container, bookmarks, URL scheme or import queue.
enum AuditLibraryFixtures {
    static func prepareIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-GopherForgeAuditFixtures"),
              Bundle.main.bundleIdentifier == "com.sergiiziborov.GopherForgeAuditQA" else { return }
        do {
            let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            for suffix in ["A", "B"] {
                let folder = documents.appending(path: "Audit-Library-\(suffix)", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appending(path: "recent-projects.json")
                guard !FileManager.default.fileExists(atPath: file.path) else { continue }
                let project = GopherForgeProject(
                    name: "Audit Project \(suffix)",
                    files: ["go.mod": GoLanguage.module("audit"), "main.go": "package main\n// QA_\(suffix)_ORIGINAL\nfunc main() {}\n"],
                    entryFile: "main.go", provenance: nil
                )
                let item = ProjectLibraryItem(id: UUID(), project: project, lastOpenedAt: Date(), sourceRevision: 0)
                try JSONEncoder.gopherForge.encode(ProjectLibraryDocument.State(items: [item]))
                    .write(to: file, options: .withoutOverwriting)
            }
        } catch { assertionFailure("QA fixture preparation failed: \(error)") }
    }
}
#endif
