import SwiftUI

/// Idiom suggestions, each with the reason and, where it is safe, a repair.
struct IdiomFindingListView: View {
    @Environment(WorkspaceModel.self) private var workspace
    let findings: [IdiomFinding]

    var body: some View {
        if findings.isEmpty {
            EmptyDockMessage(
                systemImage: "wand.and.stars",
                title: "Nothing to suggest",
                message: "The idiom coach reads the code as you type."
            ,
                tint: WorkspacePane.idioms.tint
            )
        } else {
            List(findings) { finding in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(GopherForgeTheme.accent)
                        Text(finding.title).font(.callout.weight(.medium))
                        Spacer()
                        Text(finding.confidence == .certain ? "convention" : "worth a look")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(finding.fileName):\(finding.line)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(finding.explanation)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)

                    if finding.isAutoRepairable {
                        Button("Apply") {
                            workspace.applyIdiom(finding)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.plain)
        }
    }
}
