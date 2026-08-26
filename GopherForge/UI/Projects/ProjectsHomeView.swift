import SwiftUI

/// Recent projects and the ways to start a new one.
struct ProjectsHomeView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var recents: [ProjectLibraryItem] = []
    @State private var isCreating = false
    private let library = ProjectLibrary()

    var body: some View {
        List {
            Section("Start") {
                Button {
                    isCreating = true
                } label: {
                    Label("New project", systemImage: "plus.square.on.square")
                }
            }

            if !recents.isEmpty {
                Section("Recent") {
                    ForEach(recents) { item in
                        Button {
                            workspace.open(item.project)
                        } label: {
                            ProjectRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .sheet(isPresented: $isCreating) {
            NewProjectSheet { project in
                workspace.open(project)
                Task { await reload() }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        recents = (try? await library.items()) ?? []
    }
}

private struct ProjectRow: View {
    let item: ProjectLibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(item.project.name).font(.callout.weight(.medium))
                Spacer()
                if let build = item.lastBuild {
                    Image(systemName: build.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(GopherForgeTheme.statusColor(succeeded: build.succeeded))
                }
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if let module = item.project.module { parts.append(module.modulePath) }
        parts.append("\(item.project.goFileCount) Go files")
        if item.project.testFileCount > 0 { parts.append("\(item.project.testFileCount) test files") }
        return parts.joined(separator: " · ")
    }
}
