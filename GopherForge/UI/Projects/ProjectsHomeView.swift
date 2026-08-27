import SwiftUI

/// The landing screen: what this app is, how to start, and what was open last.
///
/// The first run has no recent projects, so this screen has to carry the
/// product on its own rather than showing an empty list.
struct ProjectsHomeView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(AppNavigation.self) private var navigation
    @State private var recents: [ProjectLibraryItem] = []
    @State private var pendingImports: [PendingImportDrain.Pending] = []
    @State private var isImporting = false
    @State private var importFailure: String?
    private let library = ProjectLibrary()

    var body: some View {
        List {
            if recents.isEmpty {
                Section {
                    WelcomeCard()
                        .accessibilityIdentifier(AccessibilityID.welcomeCard)
                }
            }

            if !pendingImports.isEmpty {
                Section("Shared with GopherForge") {
                    ForEach(pendingImports) { pending in
                        Label(pending.reference.displayName, systemImage: "square.and.arrow.down")
                            .font(.callout)
                    }
                    Text("Repository import arrives with the network work; the link is kept until then.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Start a project") {
                ForEach(ProjectTemplate.all) { template in
                    Button {
                        open(template.project(named: template.title))
                    } label: {
                        TemplateRow(template: template)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.template(template.id))
                }

                Button {
                    isImporting = true
                } label: {
                    Label("Open a folder from Files", systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier(AccessibilityID.openFolder)
            }

            if !recents.isEmpty {
                Section("Recent") {
                    ForEach(recents) { item in
                        Button {
                            open(item.project)
                        } label: {
                            ProjectRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: remove)
                }
            }

            if let importFailure {
                Section {
                    Label(importFailure, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Projects")
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.folder, GopherForgeProjectDocument.contentType],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .task { await reload() }
    }

    private func open(_ project: GopherForgeProject) {
        workspace.open(project)
        navigation.show(.build)
        Task { await reload() }
    }

    private func remove(at offsets: IndexSet) {
        let ids = offsets.map { recents[$0].id }
        Task {
            for id in ids { _ = try? await library.remove(id: id) }
            await reload()
        }
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        importFailure = nil
        guard case let .success(urls) = result, let url = urls.first else {
            if case let .failure(error) = result { importFailure = error.localizedDescription }
            return
        }

        // A picked folder lives outside the app container, so access has to be
        // opened explicitly and closed again whatever happens.
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let project = url.pathExtension == "gopherforgeproject"
                ? try GopherForgeProjectDocument.read(from: url)
                : try LocalProjectLoader().load(from: url)
            open(project)
        } catch {
            importFailure = error.localizedDescription
        }
    }

    private func reload() async {
        recents = (try? await library.items()) ?? []
        if pendingImports.isEmpty {
            pendingImports = PendingImportDrain().drain()
        }
    }
}

/// Shown only on a first run, where an empty list would say nothing.
private struct WelcomeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forge real Go, anywhere.")
                .font(.title3.weight(.semibold))
            Text("""
            A real Go toolchain, a course written for people who already \
            program, and a lab that shows what your goroutines actually did — \
            all on this device, with no network.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

private struct TemplateRow: View {
    let template: ProjectTemplate

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: template.systemImage)
                .foregroundStyle(GopherForgeTheme.ember)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.title).font(.callout.weight(.medium))
                Text(template.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .contentShape(Rectangle())
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
