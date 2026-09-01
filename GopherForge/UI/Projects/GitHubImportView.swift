import SwiftUI

/// Paste a repository URL, get the code.
struct GitHubImportView: View {
    @State private var model = GitHubImportModel()
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
                            + "not its history. A link to a branch or a commit brings that "
                            + "revision instead of the default one.")
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
                        Task {
                            if let project = await model.importRepository() {
                                onImport(project)
                                dismiss()
                            }
                        }
                    } label: {
                        if model.isDownloading {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Downloading…")
                            }
                        } else {
                            Label("Import repository", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(!model.canImport)
                    .accessibilityIdentifier(AccessibilityID.githubImportButton)
                } footer: {
                    Text("Only text files are brought across, and binaries, `.git` and "
                        + "`testdata` are left behind. Everything imported is source you "
                        + "can read and edit here.")
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
}
