import SwiftUI
import UniformTypeIdentifiers

/// The landing screen: what this app is, how to start, and what was open last.
///
/// The first run has no recent projects, so this screen has to carry the
/// product on its own rather than showing an empty list.
struct ProjectsHomeView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(AppNavigation.self) private var navigation
    @State private var filePick: FilePick?
    @State private var recents: [ProjectLibraryItem] = []
    @State private var pendingImports: [PendingImportDrain.Pending] = []
    /// The pending import currently downloading, so its row can show it.
    @State private var importingShared: String?
    @State private var importFailure: String?
    private let library = ProjectLibrary.shared

    private var libraryFolders: [String] {
        Array(Set(recents.map(\.folderLabel)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

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
                    NewProjectView(existingFolders: libraryFolders) { create($0) }
                } label: {
                    NewProjectRow()
                }
                .accessibilityIdentifier(AccessibilityID.newProject)

                NavigationLink {
                    MyProjectsView(
                        items: recents,
                        onOpen: { open($0) },
                        onToggleFavorite: toggleFavorite,
                        onOrganize: organize,
                        onDuplicate: duplicate,
                        onDelete: delete
                    )
                } label: {
                    LabeledContent {
                        Text("\(recents.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Project library", systemImage: "square.grid.2x2")
                    }
                }
                .accessibilityIdentifier(AccessibilityID.libraryEntry)

                Button {
                    filePick = .openProject
                } label: {
                    Label("Open from iCloud or Files", systemImage: "icloud.and.arrow.down")
                }
                .accessibilityIdentifier(AccessibilityID.openFromCloud)

                Button {
                    filePick = .libraryFolder
                } label: {
                    Label(
                        "Keep library in iCloud…",
                        systemImage: "externaldrive.badge.icloud"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.keepLibraryInCloud)

                if ProjectLibraryLocation.usesChosenFolder {
                    Button {
                        Task {
                            do {
                                recents = try await library.useOnDeviceLibrary()
                            } catch {
                                importFailure = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Keep library on this device", systemImage: "internaldrive")
                    }
                }
            } footer: {
                Text("Projects stay on this device unless you pick an iCloud Drive "
                    + "or Files folder for the library. Export a project from its "
                    + "file menu — in Project library, or the ⋯ menu in the editor.")
            }

            if !recents.isEmpty {
                Section {
                    // A strip, not the library: five is what fits without the
                    // first screen becoming a wall, and everything else is one
                    // tap away in Project library.
                    ForEach(recents.prefix(ProjectHomeLimits.recentCount)) { item in
                        Button {
                            open(item)
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
                    if recents.count > ProjectHomeLimits.recentCount {
                        Text("\(recents.count - ProjectHomeLimits.recentCount) more in Project library.")
                    }
                }
            }

            Section {
                NavigationLink {
                    ExampleLibraryView()
                } label: {
                    LabeledContent {
                        Text("\(GoExampleLibrary.all.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Examples", systemImage: "curlybraces")
                    }
                }
                .accessibilityIdentifier(AccessibilityID.projectsExamples)
            } footer: {
                Text("Browse runnable programs and site projects in their own library.")
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
            isPresented: Binding(
                get: { filePick != nil },
                set: { if !$0 { filePick = nil } }
            ),
            allowedContentTypes: filePick?.contentTypes ?? [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result)
        }
        .task {
            await reload()
            if LaunchOptions.initialScreen == .packages, let first = recents.first {
                open(first)
            }
        }
    }

    private func handleFilePick(_ result: Result<[URL], any Error>) {
        let pick = filePick
        filePick = nil
        importFailure = nil
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            switch pick {
            case .libraryFolder:
                Task {
                    do {
                        recents = try await library.adoptFolder(url)
                    } catch {
                        importFailure = error.localizedDescription
                    }
                }
            case .openProject, .none:
                do {
                    open(try LocalProjectImporter.loadPicked(at: url))
                } catch {
                    importFailure = error.localizedDescription
                }
            }
        case let .failure(error):
            importFailure = error.localizedDescription
        }
    }

    private func create(_ draft: NewProjectDraft) {
        let ready = draft.annotatingStarterPackages()
        guard workspace.open(ready.project) else { return }
        finishOpening()
        let summary = ready.wantedPackages.isEmpty
            ? nil
            : "Starter packages: " + ready.wantedPackages.joined(separator: ", ")
        Task {
            await workspace.libraryUpdated()
            guard let id = workspace.projectID else { return }
            do {
                _ = try await library.update(
                    id: id,
                    name: ready.project.name,
                    folder: ready.folder,
                    tags: ready.tags,
                    summary: summary
                )
                if let refreshed = try await library.project(id: id) {
                    workspace.refreshMetadata(from: refreshed)
                }
            } catch {
                importFailure = error.localizedDescription
            }
            await reload()
        }
    }

    private func open(_ project: GopherForgeProject) {
        if workspace.open(project) { finishOpening() }
    }

    private func open(_ item: ProjectLibraryItem) {
        if workspace.open(item) { finishOpening() }
    }

    private func finishOpening() {
        navigation.show(.build)
        Task {
            // Opening writes the project into the library; waiting for that
            // write is what stops the list reloading from the state before it.
            await workspace.libraryUpdated()
            await reload()
        }
    }

    private func remove(at offsets: IndexSet) {
        let shown = Array(recents.prefix(ProjectHomeLimits.recentCount))
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
            do {
                _ = try await library.update(
                    id: item.id,
                    name: draft.trimmedName,
                    folder: draft.folder,
                    tags: draft.tags,
                    isFavorite: draft.isFavorite,
                    summary: draft.summary
                )
                if let refreshed = try await library.project(id: item.id) {
                    workspace.refreshMetadata(from: refreshed)
                }
            } catch {
                importFailure = "Не удалось сохранить проект: \(error.localizedDescription)"
            }
            await reload()
        }
    }

    private func duplicate(_ item: ProjectLibraryItem, named name: String) {
        Task {
            do {
                guard let copy = try await library.duplicate(id: item.id, named: name) else {
                    importFailure = "The original project is no longer in the library."
                    return
                }
                recents = try await library.items()
                open(copy)
            } catch {
                importFailure = "Could not duplicate the project: \(error.localizedDescription)"
            }
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

/// How many recent projects the first screen keeps visible.
enum ProjectHomeLimits {
    static let recentCount = 5
}

/// Shown only on a first run, where an empty list would say nothing.
private struct WelcomeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forge real Go, anywhere.")
                .font(.title3.weight(.semibold))
            Text("""
            A real Go toolchain and a course written for people who already \
            program — all on this device, with no network.
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
private enum FilePick {
    case openProject
    case libraryFolder

    var contentTypes: [UTType] {
        switch self {
        case .openProject:
            [.folder, GopherForgeProjectDocument.contentType, .gzip]
        case .libraryFolder:
            [.folder]
        }
    }
}

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
