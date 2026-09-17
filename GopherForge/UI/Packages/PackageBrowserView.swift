import SwiftUI

/// Find a Go module, see what is known about it, and vendor it into a project.
///
/// The network is used here and only here. What lands in the project is source
/// under `vendor/`, so every build afterwards is offline — which is why this
/// screen says so rather than leaving it to be discovered.
struct PackageBrowserView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(AppNavigation.self) private var navigation
    @State private var model = PackageInstallModel()
    @State private var libraryItems: [ProjectLibraryItem] = []
    @State private var targetID: UUID?

    /// From the Projects list a package can go into any project. From a
    /// project's own sidebar it already has a target.
    var allowsProjectChoice: Bool = true
    var initialQuery: String = ""
    var onInstalled: () -> Void = {}

    var body: some View {
        @Bindable var model = model

        List {
            if allowsProjectChoice {
                projectSection
            }

            if let resolved = model.resolved {
                ResolvedModuleSection(
                    resolved: resolved,
                    selectedVersion: model.selectedVersion,
                    isBusy: model.isBusy,
                    canInstall: canInstall,
                    onSelect: model.select,
                    onInstall: install
                )
            }

            if case let .installed(summary) = model.phase {
                Section {
                    Label(summary, systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.footnote)
                        .accessibilityIdentifier(AccessibilityID.packageInstalled)
                }
            }

            if case let .failed(message) = model.phase {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(GopherForgeTheme.warning)
                        .font(.footnote)
                        .accessibilityIdentifier(AccessibilityID.packageError)
                }
            }

            if model.canResolveTypedPath {
                Section {
                    Button {
                        Task { await model.resolve(path: model.trimmedQuery) }
                    } label: {
                        Label("Look up \(model.trimmedQuery)", systemImage: "magnifyingglass")
                    }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier(AccessibilityID.packageLookup)
                }
            }

            if !model.newSearchResults.isEmpty {
                Section {
                    ForEach(model.newSearchResults) { result in
                        Button {
                            Task { await model.resolve(path: result.path) }
                        } label: {
                            SearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("package.\(result.path)")
                    }
                } header: {
                    Text("From the Go ecosystem")
                }
            }

            Section {
                ForEach(model.catalogMatches) { entry in
                    Button {
                        Task { await model.resolve(path: entry.path) }
                    } label: {
                        CatalogRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("package.\(entry.path)")
                }
            } header: {
                Text(model.query.isEmpty ? "Widely used" : "Matching")
            } footer: {
                Text("Search matches package **names**, not descriptions — \"uuid\" finds "
                    + "one, \"http router\" finds nothing. Type a module path in full to "
                    + "install anything else. Every download is checked against the official "
                    + "Go checksum database before a single file is written, and the source "
                    + "is vendored into the project so builds stay offline.")
            }
        }
        .searchable(text: $model.query, prompt: "Package name or module path")
        .onChange(of: model.query) { _, _ in model.searchAfterTyping() }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle("Packages")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.isBusy { ProgressView().controlSize(.large) }
        }
        .overlay(alignment: .top) {
            if model.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .padding(6)
            }
        }
        .task {
            if !initialQuery.isEmpty, model.query.isEmpty {
                model.query = initialQuery
                model.searchAfterTyping()
            }
            await reloadLibrary()
        }
    }

    @ViewBuilder
    private var projectSection: some View {
        Section {
            if libraryItems.isEmpty {
                Text("Create or open a project first. A package is installed into one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Add to", selection: targetBinding) {
                    ForEach(libraryItems) { item in
                        Text(item.project.name).tag(Optional(item.id))
                    }
                }
                .accessibilityIdentifier(AccessibilityID.packageTarget)
            }
        } header: {
            Text("Project")
        }
    }

    private var targetBinding: Binding<UUID?> {
        Binding(
            get: { targetID ?? workspace.projectID ?? libraryItems.first?.id },
            set: { targetID = $0 }
        )
    }

    private var canInstall: Bool {
        if allowsProjectChoice {
            return (targetID ?? workspace.projectID ?? libraryItems.first?.id) != nil
        }
        return workspace.project != nil
    }

    private func install() {
        Task {
            if allowsProjectChoice,
               let chosen = targetID ?? workspace.projectID ?? libraryItems.first?.id,
               chosen != workspace.projectID,
               let item = libraryItems.first(where: { $0.id == chosen }) {
                guard workspace.open(item) else { return }
                await workspace.libraryUpdated()
            }

            guard let project = workspace.project,
                  let updated = await model.install(into: project.files)
            else {
                return
            }
            workspace.replaceFiles(with: updated)
            onInstalled()
            if allowsProjectChoice {
                navigation.show(.build)
            }
        }
    }

    private func reloadLibrary() async {
        libraryItems = (try? await ProjectLibrary.shared.items()) ?? []
        if targetID == nil {
            targetID = workspace.projectID ?? libraryItems.first?.id
        }
    }
}

private struct CatalogRow: View {
    let entry: GoPackageCatalog.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.path).font(.callout.monospaced())
            Text(entry.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

/// A module the search found, with the version it is published at.
private struct SearchResultRow: View {
    let result: GoPackageSearchClient.Result

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "shippingbox")
                .foregroundStyle(GopherForgeTheme.slate)
                .font(.caption)
            Text(result.path).font(.callout.monospaced())
            Spacer(minLength: 6)
            if let version = result.defaultVersion {
                Text(version)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
