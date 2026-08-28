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
            }

            Section {
                NavigationLink {
                    PackageBrowserView()
                } label: {
                    Label("Add a package", systemImage: "shippingbox")
                }
                .disabled(workspace.project == nil)
                .accessibilityIdentifier(AccessibilityID.packagesEntry)

                if let project = workspace.project, let archive = exportURL(for: project) {
                    ShareLink(item: archive) {
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

    /// Writes the archive to a temporary file for the share sheet, which needs
    /// something on disk rather than bytes in memory.
    ///
    /// Nil rather than an error if it cannot be written: the row simply does
    /// not appear, which is better than a button that fails when pressed.
    private func exportURL(for project: GopherForgeProject) -> URL? {
        let name = ProjectArchiveNaming.archiveName(for: project.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            let root = ProjectArchiveNaming.rootDirectory(for: project.name)
            let data = try ProjectArchive.gzip(
                ProjectArchive.tar(files: project.files, root: root)
            )
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
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

private struct ProjectRow: View {
    let item: ProjectLibraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.callout)
                .foregroundStyle(GopherForgeTheme.anvil)
                .frame(width: 28, height: 28)
                .background(GopherForgeTheme.anvil.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.project.name).font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // The last build as a chip rather than a bare tick: "3 tests"
                // and "build failed" are different facts, and a tick says
                // neither of them.
                BuildOutcomeChip(record: item.lastBuild)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
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

/// The single way in to starting something, on a screen whose job is otherwise
/// to show what you were already working on.
private struct NewProjectRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(GopherForgeTheme.ember, in: RoundedRectangle(cornerRadius: 8))

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
