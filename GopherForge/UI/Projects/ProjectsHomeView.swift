import SwiftUI

/// The landing screen: what this app is, how to start, and what was open last.
///
/// The first run has no recent projects, so this screen has to carry the
/// product on its own rather than showing an empty list.
struct ProjectsHomeView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var isShowingPackages = false
    @Environment(AppNavigation.self) private var navigation
    @State private var recents: [ProjectLibraryItem] = []
    @State private var pendingImports: [PendingImportDrain.Pending] = []
    /// The pending import currently downloading, so its row can show it.
    @State private var importingShared: String?
    @State private var importFailure: String?
    private let library = ProjectLibrary.shared

    var body: some View {
        List {
            if recents.isEmpty {
                Section {
                    WelcomeCard()
                        .accessibilityIdentifier(AccessibilityID.welcomeCard)
                }
            }

            if !pendingImports.isEmpty {
                Section {
                    ForEach(pendingImports) { pending in
                        Button {
                            importShared(pending)
                        } label: {
                            HStack(spacing: 10) {
                                Label(pending.reference.displayName, systemImage: "square.and.arrow.down")
                                    .font(.callout)
                                Spacer(minLength: 0)
                                if importingShared == pending.id {
                                    ProgressView()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(importingShared != nil)
                    }
                } header: {
                    Text("Shared with GopherForge")
                } footer: {
                    Text("Sent here from another app. Tap to download the repository.")
                }
            }

            Section {
                NavigationLink {
                    NewProjectView { open($0) }
                } label: {
                    NewProjectRow()
                }
                .accessibilityIdentifier(AccessibilityID.newProject)

                if !recents.isEmpty {
                    NavigationLink {
                        MyProjectsView(
                            items: recents,
                            onOpen: { open($0.project) },
                            onToggleFavorite: toggleFavorite,
                            onOrganize: organize,
                            onDelete: delete
                        )
                    } label: {
                        LabeledContent {
                            Text("\(recents.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("My projects", systemImage: "square.grid.2x2")
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.libraryEntry)
                }
            }

            Section {
                NavigationLink {
                    PackageBrowserView()
                } label: {
                    Label("Add a package", systemImage: "shippingbox")
                }
                .disabled(workspace.project == nil)
                .accessibilityIdentifier(AccessibilityID.packagesEntry)

                if let project = workspace.project {
                    ShareLink(
                        item: ProjectExport(project: project),
                        preview: SharePreview(project.name)
                    ) {
                        Label("Export \(project.name) as .tar.gz", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier(AccessibilityID.exportProject)
                }
            } footer: {
                Text(workspace.project == nil
                    ? "Open a project first; a package is installed into one."
                    : "Downloads are checked against the Go checksum database and vendored "
                        + "into the project, so builds stay offline afterwards.")
            }

            if !recents.isEmpty {
                Section {
                    // A strip, not the library: five is what fits without the
                    // first screen becoming a wall, and everything else is one
                    // tap away in My projects.
                    ForEach(recents.prefix(5)) { item in
                        Button {
                            open(item.project)
                        } label: {
                            ProjectLibraryRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.project(item.id))
                    }
                    .onDelete(perform: remove)
                } header: {
                    Text("Recent")
                } footer: {
                    if recents.count > 5 {
                        Text("\(recents.count - 5) more in My projects.")
                    }
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
        .navigationDestination(isPresented: $isShowingPackages) { PackageBrowserView() }
        .task {
            await reload()
            // Automation opens the package browser directly; the section it
            // belongs to is this one, so the destination lives here.
            if LaunchOptions.initialScreen == .packages, workspace.project != nil {
                isShowingPackages = true
            }
        }
    }

    private func open(_ project: GopherForgeProject) {
        workspace.open(project)
        navigation.show(.build)
        Task {
            // Opening writes the project into the library; waiting for that
            // write is what stops the list reloading from the state before it.
            await workspace.libraryUpdated()
            await reload()
        }
    }

    private func remove(at offsets: IndexSet) {
        let shown = Array(recents.prefix(5))
        let ids = offsets.compactMap { shown.indices.contains($0) ? shown[$0].id : nil }
        Task {
            for id in ids { _ = try? await library.remove(id: id) }
            await reload()
        }
    }

    /// Downloads a repository the share extension queued while the app was
    /// not running.
    private func importShared(_ pending: PendingImportDrain.Pending) {
        importingShared = pending.id
        importFailure = nil
        Task {
            defer { importingShared = nil }
            do {
                let project = try await GitHubRepositoryImporter()
                    .importRepository(pending.reference)
                pendingImports.removeAll { $0.id == pending.id }
                open(project)
            } catch {
                importFailure = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    private func toggleFavorite(_ item: ProjectLibraryItem) {
        Task {
            _ = try? await library.setFavorite(id: item.id, !item.favorite)
            await reload()
        }
    }

    private func organize(_ item: ProjectLibraryItem, _ draft: ProjectFilingDraft) {
        Task {
            _ = try? await library.update(
                id: item.id,
                name: draft.trimmedName,
                folder: draft.folder,
                tags: draft.tags,
                isFavorite: draft.isFavorite,
                summary: draft.summary
            )
            await reload()
        }
    }

    private func delete(_ item: ProjectLibraryItem) {
        Task {
            _ = try? await library.remove(id: item.id)
            await reload()
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

/// The single way in to starting something, on a screen whose job is otherwise
/// to show what you were already working on.
private struct NewProjectRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(GopherForgeTheme.accent, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Create new project").font(.callout.weight(.medium))
                Text("A template, a GitHub repository, or a folder from Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
