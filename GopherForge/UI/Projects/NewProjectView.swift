import SwiftUI
import UniformTypeIdentifiers

/// What the create screen hands back: the project, and how to file it.
struct NewProjectDraft: Equatable {
    var project: GopherForgeProject
    var folder: String
    var tags: [String]
    var wantedPackages: [String]

    /// Writes the chosen package paths onto `go.mod` as comments so they live
    /// in the project, not only on the library card. They are not vendored
    /// here: a template must still build offline.
    func annotatingStarterPackages() -> NewProjectDraft {
        guard !wantedPackages.isEmpty else { return self }
        var files = project.files
        var goMod = files["go.mod"] ?? ""
        if !goMod.hasSuffix("\n") { goMod += "\n" }
        if !goMod.contains("Starter packages") {
            goMod += "\n// Starter packages to vendor from the project menu:\n"
            for path in wantedPackages {
                goMod += "//\t\(path)\n"
            }
        }
        files["go.mod"] = goMod
        return NewProjectDraft(
            project: GopherForgeProject(
                name: project.name,
                files: files,
                entryFile: project.entryFile,
                provenance: project.provenance
            ),
            folder: folder,
            tags: tags,
            wantedPackages: wantedPackages
        )
    }
}

/// Every way a project can begin, in one place.
///
/// A template tap used to materialise a project named after the template —
/// "Command-line tool" as a title nobody chose. Naming, tags, a folder and
/// optional starter packages are one screen between the template and the
/// editor, so the first thing in the library is something the owner named.
struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    let existingFolders: [String]
    let onCreate: (NewProjectDraft) -> Void

    @State private var selectedTemplate: ProjectTemplate?
    @State private var name = ""
    @State private var folder = ""
    @State private var tagsText = ""
    @State private var wantedPackages: Set<String> = []
    @State private var isImportingFile = false
    @State private var isImportingRepository = false
    @State private var failure: String?

    private var suggestions: [String] {
        existingFolders.filter { $0 != ProjectLibraryItem.looseFolder }
    }

    private var starterPackages: [GoPackageCatalog.Entry] {
        Array(GoPackageCatalog.entries.prefix(8))
    }

    var body: some View {
        Group {
            if let template = selectedTemplate {
                configure(template)
            } else {
                picker
            }
        }
        .navigationTitle(selectedTemplate == nil ? "New project" : "Name this project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTemplate != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Templates") { selectedTemplate = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createFromTemplate() }
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier(AccessibilityID.newProjectCreate)
                }
            }
        }
        .sheet(isPresented: $isImportingRepository) {
            GitHubImportView { openImported($0) }
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [
                .folder,
                GopherForgeProjectDocument.contentType,
                .gzip,
            ],
            allowsMultipleSelection: false
        ) { result in
            handle(result)
        }
    }

    // MARK: - Template picker

    private var picker: some View {
        List {
            Section {
                ForEach(ProjectTemplate.all) { template in
                    Button {
                        selectedTemplate = template
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            name = template.title
                        }
                    } label: {
                        TemplateTile(template: template)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.template(template.id))
                }
            } header: {
                Text("From a template")
            } footer: {
                Text("Next you name it, and you can add tags or starter packages. "
                    + "The project is not created until you tap Create.")
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
    }

    // MARK: - Name, tags, packages

    private func configure(_ template: ProjectTemplate) -> some View {
        Form {
            Section {
                Label(template.title, systemImage: template.systemImage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } footer: {
                Text(template.summary)
            }

            Section {
                TextField("Project name", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(AccessibilityID.newProjectName)
            } header: {
                Text("Name")
            } footer: {
                Text("This is the name in Project library, not the template you started from.")
            }

            Section {
                TextField("Folder", text: $folder)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier(AccessibilityID.newProjectFolder)
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { item in
                                Button(item) { folder = item }
                                    .buttonStyle(.plain)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        GopherForgeTheme.accentWash(),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(GopherForgeTheme.accent)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Folder")
            } footer: {
                Text("Leave it empty to keep the project loose.")
            }

            Section {
                TextField("cli, parser, wip", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(AccessibilityID.newProjectTags)
            } header: {
                Text("Tags")
            } footer: {
                Text("Separated by commas. Optional.")
            }

            Section {
                ForEach(starterPackages) { entry in
                    Button {
                        if wantedPackages.contains(entry.path) {
                            wantedPackages.remove(entry.path)
                        } else {
                            wantedPackages.insert(entry.path)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: wantedPackages.contains(entry.path)
                                ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    wantedPackages.contains(entry.path)
                                        ? GopherForgeTheme.accent : Color.secondary
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.path)
                                    .font(.caption.monospaced())
                                Text(entry.blurb)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.newProjectPackage(entry.path))
                }
            } header: {
                Text("Starter packages")
            } footer: {
                Text("Optional. They are noted on the project; vendor them from "
                    + "the project menu once you are in the editor. Export lives "
                    + "in that same menu, not on the Projects list.")
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createFromTemplate() {
        guard let template = selectedTemplate, !trimmedName.isEmpty else { return }
        finish(
            NewProjectDraft(
                project: template.project(named: trimmedName),
                folder: folder,
                tags: ProjectLibraryItem.normalizedTags(tagsText),
                wantedPackages: wantedPackages.sorted()
            )
        )
    }

    private func openImported(_ project: GopherForgeProject) {
        finish(NewProjectDraft(project: project, folder: "", tags: [], wantedPackages: []))
    }

    private func finish(_ draft: NewProjectDraft) {
        onCreate(draft)
        dismiss()
    }

    private func handle(_ result: Result<[URL], any Error>) {
        failure = nil
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            do {
                openImported(try LocalProjectImporter.loadPicked(at: url))
            } catch {
                failure = error.localizedDescription
            }
        case let .failure(error):
            failure = error.localizedDescription
        }
    }
}
