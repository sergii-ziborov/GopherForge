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
                Text("Go has no package search API, so this is a starting list plus "
                    + "anything you type in full. Every download is checked against the "
                    + "official Go checksum database before a single file is written, and "
                    + "the source is vendored into the project so builds stay offline.")
            }
        }
        .searchable(text: $model.query, prompt: "Module path or keyword")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle("Packages")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.isBusy { ProgressView().controlSize(.large) }
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
