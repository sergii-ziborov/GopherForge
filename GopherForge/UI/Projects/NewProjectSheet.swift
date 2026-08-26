import SwiftUI

/// Creates a project from one of the offline templates.
struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Forge"
    @State private var template = ProjectTemplate.commandLineTool
    let onCreate: (GopherForgeProject) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Project name", text: $name)
                        .autocorrectionDisabled()
                    HStack {
                        Text("Module path")
                        Spacer()
                        Text(ProjectTemplate.modulePath(for: name))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(ProjectTemplate.all) { item in
                        Button {
                            template = item
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.systemImage)
                                    .foregroundStyle(GopherForgeTheme.ember)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.callout.weight(.medium))
                                    Text(item.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                if template.id == item.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(GopherForgeTheme.ember)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Template")
                } footer: {
                    Text("Every template builds offline against the bundled standard library and declares no dependencies.")
                }
            }
            .navigationTitle("New project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(template.project(named: name.isEmpty ? "Forge" : name))
                        dismiss()
                    }
                }
            }
        }
    }
}
