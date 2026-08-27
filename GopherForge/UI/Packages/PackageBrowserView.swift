import SwiftUI

/// Find a Go module, see what is known about it, and vendor it into the open
/// project.
///
/// The network is used here and only here. What lands in the project is source
/// under `vendor/`, so every build afterwards is offline — which is why this
/// screen says so rather than leaving it to be discovered.
struct PackageBrowserView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var model = PackageInstallModel()

    var body: some View {
        @Bindable var model = model

        List {
            if let resolved = model.resolved {
                ResolvedModuleSection(
                    resolved: resolved,
                    selectedVersion: model.selectedVersion,
                    isBusy: model.isBusy,
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
                        .foregroundStyle(.orange)
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
    }

    private func install() {
        Task {
            guard let project = workspace.project,
                  let updated = await model.install(into: project.files)
            else {
                return
            }
            workspace.replaceFiles(with: updated)
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
                .foregroundStyle(GopherForgeTheme.anvil)
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
