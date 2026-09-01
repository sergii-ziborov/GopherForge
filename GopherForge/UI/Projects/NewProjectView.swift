import SwiftUI

/// Every way a project can begin, in one place.
///
/// The home screen used to list the templates inline under "Start a project",
/// which made the first thing a returning person saw a wall of things they had
/// already chosen from. Starting a project is one decision, so it is one row —
/// and this is what it opens.
struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    /// The caller owns what opening means; this screen only produces a project.
    let onCreate: (GopherForgeProject) -> Void

    @State private var isImportingFile = false
    @State private var isImportingRepository = false
    @State private var failure: String?

    var body: some View {
        List {
            Section {
                ForEach(ProjectTemplate.all) { template in
                    Button {
                        create(template.project(named: template.title))
                    } label: {
                        TemplateTile(template: template)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.template(template.id))
                }
            } header: {
                Text("From a template")
            } footer: {
                Text("Every template builds and runs as it stands, so the first thing "
                    + "you do can be changing it rather than fixing it.")
            }

            Section {
                Button {
                    isImportingRepository = true
                } label: {
                    Label("Import from GitHub", systemImage: "arrow.down.circle")
                }
                .accessibilityIdentifier(AccessibilityID.githubImportEntry)

                Button {
                    isImportingFile = true
                } label: {
                    Label("Open a folder or archive from Files", systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier(AccessibilityID.openFolder)
            } header: {
                Text("From code that already exists")
            } footer: {
                Text("A public GitHub repository, a folder of Go source, or a `.tar.gz` "
                    + "this app exported earlier.")
            }

            if let failure {
                Section {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(GopherForgeTheme.warning)
                }
            }
        }
        .navigationTitle("New project")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isImportingRepository) {
            GitHubImportView { create($0) }
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [
                .folder,
                GopherForgeProjectDocument.contentType,
                // A tar.gz is what the rest of the world already opens, so it
                // is what an exported project should be able to come back as.
                .gzip,
            ],
            allowsMultipleSelection: false
        ) { result in
            handle(result)
        }
    }

    private func create(_ project: GopherForgeProject) {
        onCreate(project)
        dismiss()
    }

    private func handle(_ result: Result<[URL], any Error>) {
        failure = nil
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            do {
                create(try LocalProjectImporter.loadPicked(at: url))
            } catch {
                failure = error.localizedDescription
            }
        case let .failure(error):
            failure = error.localizedDescription
        }
    }
}
