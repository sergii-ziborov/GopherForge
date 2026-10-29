import SwiftUI

/// Paste a repository URL, get the code.
struct GitHubImportView: View {
    @State private var model = GitHubImportModel()
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(\.dismiss) private var dismiss
    /// Called with the imported project, so the caller decides what opening
    /// means — this screen only knows how to fetch one.
    let onImport: (GopherForgeProject) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://github.com/owner/repository", text: $model.rawURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.callout.monospaced())
                        .accessibilityIdentifier(AccessibilityID.githubURLField)

                    if let reference = model.reference {
                        LabeledContent("Repository", value: reference.displayName)
                            .font(.callout)
                        if let ref = reference.reference {
                            LabeledContent("Branch or commit", value: ref)
                                .font(.callout)
                        }
                    }
                } header: {
                    Text("Repository URL")
                } footer: {
                    if let message = model.validationMessage {
                        Text(message).foregroundStyle(GopherForgeTheme.warning)
                    } else {
                        Text("A public repository is downloaded as a snapshot — the code, "
                            + "not its history. The requested branch or tag is resolved to a "
                            + "fixed commit before downloading.")
                    }
                }

                if case let .failed(message) = model.phase {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(GopherForgeTheme.warning)
                            .accessibilityIdentifier(AccessibilityID.githubImportFailure)
                    }
                }

                Section {
                    Button {
                        Task { await importRepository() }
                    } label: {
                        if model.isDownloading {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(model.statusText)
                            }
                        } else {
                            Label("Import repository", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(!model.canImport)
                    .accessibilityIdentifier(AccessibilityID.githubImportButton)
                } footer: {
                    Text("The repository snapshot is downloaded, then the modules in "
                        + "go.mod that the program imports are added so it can build offline. "
                        + "UTF-8 testdata, vendor and frontend source are retained within limits. "
                        + "Binary assets and other omissions are listed in Project → Import details; "
                        + "export contains only the imported text snapshot.")
                }
            }
            .navigationTitle("Import from GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func importRepository() async {
        guard let reference = model.reference else { return }
        model.note("Downloading \(reference.displayName)…")
        do {
            let project = try await workspace.importGitHub(reference)
            model.finish()
            onImport(project)
            dismiss()
        } catch {
            model.fail((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
