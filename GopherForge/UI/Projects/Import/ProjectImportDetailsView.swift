import SwiftUI

struct ProjectImportDetailsView: View {
    let project: GopherForgeProject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Snapshot") {
                    Text("Import copies a bounded text snapshot. It does not edit the original folder and does not clone Git history. Export contains the current snapshot, including your edits; omitted assets cannot be recreated by export.")
                    if let report = project.provenance?.importReport {
                        LabeledContent("Retained at import", value: "\(report.retainedPaths.count) files")
                        LabeledContent("Omitted entries", value: "\(report.omissionCount)")
                        if let scope = report.scopeNote { Text(scope).foregroundStyle(.secondary) }
                    } else {
                        Text("This older import has no inventory. Its completeness has not been verified.").foregroundStyle(.secondary)
                    }
                }
                if let origin = project.provenance {
                    Section("Origin") {
                        if let owner = origin.owner, let repo = origin.repository { Text("\(owner)/\(repo)") }
                        if let ref = origin.reference { LabeledContent("Requested ref", value: ref) }
                        if let commit = origin.commit { Text("Commit: \(commit)").textSelection(.enabled).font(.caption.monospaced()) }
                        if let digest = origin.importReport?.archiveSHA256 { Text("Archive SHA-256: \(digest)").textSelection(.enabled).font(.caption.monospaced()) }
                        Text(origin.importedAt, style: .date)
                    }
                }
                if let report = project.provenance?.importReport {
                    if !report.reasons.isEmpty {
                        Section("Omissions by reason") {
                            ForEach(report.reasons.keys.sorted(), id: \.self) { reason in
                                LabeledContent(reason, value: "\(report.reasons[reason, default: 0])")
                            }
                        }
                    }
                    Section("Omitted paths") {
                        ForEach(Array(report.omissions.enumerated()), id: \.offset) { _, omission in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(omission.path).font(.caption.monospaced()).textSelection(.enabled)
                                Text(omission.reason).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if report.omissionCount > report.omissions.count {
                            Text("Showing the first \(report.omissions.count) omitted paths. The totals above include all omissions.").font(.caption)
                        }
                        if report.omissionCount == 0 { Text("No entries omitted within the selected import scope.") }
                    }
                }
            }
            .navigationTitle("Import details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
