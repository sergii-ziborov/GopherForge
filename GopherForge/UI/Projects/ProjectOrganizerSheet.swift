import SwiftUI

/// What the owner can change about a project without opening it.
struct ProjectFilingDraft: Equatable {
    var name: String
    var folder: String
    var tagsText: String
    var summary: String
    var isFavorite: Bool

    init(item: ProjectLibraryItem) {
        name = item.project.name
        folder = ProjectLibraryItem.normalizedFolder(item.folder) ?? ""
        tagsText = item.tagList.joined(separator: ", ")
        summary = item.summary ?? ""
        isFavorite = item.favorite
    }

    var tags: [String] { ProjectLibraryItem.normalizedTags(tagsText) }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Renaming, filing and starring a project, in one sheet and one write.
///
/// One sheet rather than a row of separate actions because these are one
/// thought — "this is the parser experiment, it lives in Experiments" — and
/// because the library persists as a single document, where five separate
/// edits are five rewrites of the whole thing.
struct ProjectOrganizerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProjectFilingDraft

    let item: ProjectLibraryItem
    /// Folders already in use, offered rather than remembered and retyped.
    let existingFolders: [String]
    let onSave: (ProjectFilingDraft) -> Void

    init(
        item: ProjectLibraryItem,
        existingFolders: [String],
        onSave: @escaping (ProjectFilingDraft) -> Void
    ) {
        self.item = item
        self.existingFolders = existingFolders
        self.onSave = onSave
        _draft = State(initialValue: ProjectFilingDraft(item: item))
    }

    /// Real folders only: the bucket unfiled projects are grouped under is a
    /// label, not somewhere you can put something.
    private var suggestions: [String] {
        existingFolders.filter { $0 != ProjectLibraryItem.looseFolder }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Project name", text: $draft.name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(AccessibilityID.organizerName)
                }

                Section {
                    TextField("Folder", text: $draft.folder)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier(AccessibilityID.organizerFolder)

                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { folder in
                                    Button(folder) { draft.folder = folder }
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
                    Text("Leave it empty to keep the project loose. "
                        + "Loose projects are grouped under \(ProjectLibraryItem.looseFolder).")
                }

                Section {
                    TextField("go, parser, wip", text: $draft.tagsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(AccessibilityID.organizerTags)
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Separated by commas. Case is ignored, so `WIP` and `wip` are one tag.")
                }

                Section("Note") {
                    TextField(
                        "What is this project?",
                        text: $draft.summary,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                }

                Section {
                    Toggle(isOn: $draft.isFavorite) {
                        Label("Starred", systemImage: draft.isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityIdentifier(AccessibilityID.organizerFavorite)
                } footer: {
                    Text("Starred projects sort to the top, whatever else you sort by.")
                }
            }
            .navigationTitle("Organize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    // A project with no name is one nobody can find again.
                    .disabled(draft.trimmedName.isEmpty)
                    .accessibilityIdentifier(AccessibilityID.organizerSave)
                }
            }
        }
    }
}
