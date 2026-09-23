import SwiftUI

/// The file navigator: a searchable tree that lives beside the editor rather
/// than on top of it.
///
/// It was a sheet, and a sheet is the wrong shape for this. Choosing a file is
/// not a decision you make once and dismiss — it is something you do while
/// reading code, and a sheet covers the code you were reading. Here it is a
/// column on iPad and a drawer on iPhone, and either way the editor stays
/// where it was.
///
/// Vendored modules are packages, not folders. Expanding `vendor/gin-gonic`
/// into every file gin ships is how the tree stops being a map of *this*
/// project. Those rows live under Packages, where they can be added, searched
/// and removed.
struct ProjectNavigatorView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var query = ""
    @State private var isShowingPackages = false
    @State private var packageSearch = ""
    @State private var creating: Creation?
    @State private var renaming: FileTarget?
    @State private var deleting: FileTarget?
    @State private var nameDraft = ""
    @State private var fileError: String?
    /// Called after a file is chosen, so a drawer can close itself.
    var onSelect: () -> Void = {}
    /// Called after a file is chosen so the workspace can show the editor,
    /// even when the terminal or another pane was in front.
    var onOpenFile: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Files", systemImage: "folder")
                    .font(.headline)
                Spacer()
                Menu {
                    Button { beginCreating(.file, in: "") } label: {
                        Label("New file", systemImage: "doc.badge.plus")
                    }
                    .accessibilityIdentifier(AccessibilityID.newFile)
                    Button { beginCreating(.folder, in: "") } label: {
                        Label("New folder", systemImage: "folder.badge.plus")
                    }
                    .accessibilityIdentifier(AccessibilityID.newFolder)
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .accessibilityIdentifier(AccessibilityID.addFileMenu)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            ProjectSearchField(query: $query)
            if let fileError {
                HStack {
                    Text(fileError).font(.caption).foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss", systemImage: "xmark") { self.fileError = nil }
                        .labelStyle(.iconOnly)
                }
                .padding(8)
            }
            Divider()

            if query.isEmpty {
                tree
            } else {
                results
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isShowingPackages) {
            NavigationStack {
                PackageBrowserView(
                    allowsProjectChoice: false,
                    initialQuery: packageSearch
                ) {
                    isShowingPackages = false
                    packageSearch = ""
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isShowingPackages = false }
                    }
                }
            }
        }
        .alert(creating?.kind == .folder ? "New folder" : "New file", isPresented: Binding(
            get: { creating != nil },
            set: { if !$0 { creating = nil } }
        )) {
            TextField("Name", text: $nameDraft)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Create") {
                guard let creating else { return }
                do {
                    if creating.kind == .file {
                        let path = try workspace.createFile(named: nameDraft, in: creating.directory)
                        open(path, at: nil)
                    } else {
                        try workspace.createFolder(named: nameDraft, in: creating.directory)
                        query = ""
                    }
                    fileError = nil
                } catch { fileError = error.localizedDescription }
                self.creating = nil
            }
            Button("Cancel", role: .cancel) { creating = nil }
        } message: {
            Text("Add to \(creating.map { $0.directory.isEmpty ? "project root" : $0.directory } ?? "project root")")
        }
        .alert("Rename", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Name", text: $nameDraft)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Save") {
                guard let renaming else { return }
                do {
                    if renaming.isFolder {
                        try workspace.renameFolder(at: renaming.path, to: nameDraft)
                    } else {
                        try workspace.renameFile(at: renaming.path, to: nameDraft)
                    }
                    fileError = nil
                } catch { fileError = error.localizedDescription }
                self.renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text(renaming?.path ?? "")
        }
        .confirmationDialog(
            "Delete \(deleting?.path ?? "")?",
            isPresented: Binding(
                get: { deleting != nil },
                set: { if !$0 { deleting = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let deleting else { return }
                do {
                    if deleting.isFolder {
                        try workspace.deleteFolder(at: deleting.path)
                    } else {
                        try workspace.deleteFile(at: deleting.path)
                    }
                    fileError = nil
                } catch { fileError = error.localizedDescription }
                self.deleting = nil
            }
        } message: {
            Text("This removes it from this project.")
        }
    }

    // MARK: - Tree

    private var tree: some View {
        List {
            ForEach(groups, id: \.directory) { group in
                Section {
                    rows(in: group)
                } header: {
                    folderHeader(for: group)
                }
            }
            packagesSection
        }
        .listStyle(.sidebar)
    }

    private func folderHeader(for group: (directory: String, title: String, paths: [String])) -> some View {
        HStack {
            Label(group.title, systemImage: group.directory.isEmpty ? "tray.full" : "folder")
            Spacer()
            if !group.directory.isEmpty {
                Menu {
                    Button { beginCreating(.file, in: group.directory) } label: {
                        Label("New file here", systemImage: "doc.badge.plus")
                    }
                    Button { beginCreating(.folder, in: group.directory) } label: {
                        Label("New subfolder", systemImage: "folder.badge.plus")
                    }
                    Divider()
                    Button { beginRenaming(.init(path: group.directory, isFolder: true)) } label: {
                        Label("Rename folder", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleting = .init(path: group.directory, isFolder: true)
                    } label: {
                        Label("Delete folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Folder actions for \(group.directory)")
            }
        }
        .textCase(nil)
    }

    private var packagesSection: some View {
        Section {
            Button {
                openPackageBrowser()
            } label: {
                Label("Add package", systemImage: "plus")
            }
            .accessibilityIdentifier(AccessibilityID.addPackage)

            ForEach(packages) { module in
                InstalledPackageRow(module: module)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            workspace.removePackage(module.path)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .accessibilityIdentifier(AccessibilityID.packageRemove)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            workspace.removePackage(module.path)
                        } label: {
                            Label("Remove \(module.displayName)", systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text("Packages")
        } footer: {
            if packages.isEmpty {
                Text("Dependencies belong here, not in the file tree. "
                    + "Add one to vendor it into this project.")
            }
        }
    }

    private func rows(in group: (directory: String, title: String, paths: [String])) -> some View {
        ForEach(group.paths, id: \.self) { path in
            Button {
                open(path, at: nil)
            } label: {
                ProjectFileRow(
                    path: path,
                    isSelected: workspace.selectedFile == path,
                    detail: nil
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.file(path))
            .contextMenu {
                Button { beginRenaming(.init(path: path, isFolder: false)) } label: {
                    Label("Rename file", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleting = .init(path: path, isFolder: false)
                } label: {
                    Label("Delete file", systemImage: "trash")
                }
            }
        }
    }

    private func beginCreating(_ kind: Creation.Kind, in directory: String) {
        nameDraft = ""
        creating = Creation(kind: kind, directory: directory)
    }

    private func beginRenaming(_ target: FileTarget) {
        nameDraft = target.path.split(separator: "/").last.map(String.init) ?? target.path
        renaming = target
    }

    private struct Creation {
        enum Kind { case file, folder }
        let kind: Kind
        let directory: String
    }

    private struct FileTarget {
        let path: String
        let isFolder: Bool
    }

    // MARK: - Search

    /// Results grouped by file: the file once, the lines beneath it.
    ///
    /// A flat list showed `main.go` for its name and again for every line
    /// containing "main", which reads as the search stuttering rather than as
    /// one file that matched in several places.
    private var results: some View {
        List {
            Section("Packages") {
                Button {
                    openPackageBrowser(startingWith: query)
                } label: {
                    Label("Find packages matching \(query)", systemImage: "plus")
                }
                .accessibilityIdentifier(AccessibilityID.addPackage)

                ForEach(matchingPackages) { module in
                    InstalledPackageRow(module: module)
                }
            }

            if !fileResults.isEmpty {
                ForEach(fileResults) { result in
                    Section {
                        ForEach(result.lines) { line in
                            Button {
                                open(result.path, at: line.number)
                            } label: {
                                SearchLineRow(line: line, query: query)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("search.line:\(result.path):\(line.number)")
                        }

                        if result.additionalLines > 0 {
                            // Said out loud rather than truncated silently: a
                            // capped list that looks complete is a lie.
                            Text("\(result.additionalLines) more in this file")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } header: {
                        Button {
                            open(result.path, at: result.lines.first?.number)
                        } label: {
                            SearchFileHeader(result: result, query: query)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.name:\(result.path)")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var fileResults: [ProjectFileSearch.FileResult] {
        ProjectFileSearch.results(query: query, in: workspace.project?.files ?? [:])
    }

    private func openPackageBrowser(startingWith text: String = "") {
        packageSearch = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isShowingPackages = true
    }

    private func open(_ path: String, at line: Int?) {
        workspace.select(file: path, revealingLine: line)
        // The query travels with the selection so the editor can mark the same
        // occurrences the sidebar just showed.
        workspace.highlightQuery = query
        onOpenFile()
        onSelect()
    }

    private var packages: [GoVendorWriter.InstalledModule] {
        GoVendorWriter.installedModules(in: workspace.project?.files ?? [:])
    }

    private var matchingPackages: [GoVendorWriter.InstalledModule] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return packages.filter {
            $0.path.lowercased().contains(needle) || $0.displayName.lowercased().contains(needle)
        }
    }

    private var groups: [(directory: String, title: String, paths: [String])] {
        ProjectNavigatorListing.fileGroups(in: workspace.project?.files ?? [:])
    }
}

/// One installed module: the name a reader recognises, the path and version
/// underneath, and nothing of the files inside.
private struct InstalledPackageRow: View {
    let module: GoVendorWriter.InstalledModule

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "shippingbox")
                .foregroundStyle(GopherForgeTheme.slate)
                .font(.callout)
                .frame(width: 20, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(module.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(module.displayName), \(detail)")
        .accessibilityIdentifier(AccessibilityID.installedPackage(module.path))
    }

    private var detail: String {
        var parts = [module.path]
        if !module.version.isEmpty { parts.append(module.version) }
        if module.isIndirect { parts.append("indirect") }
        if !module.isVendored { parts.append("not vendored") }
        return parts.joined(separator: " · ")
    }
}

/// The project's own files, grouped by directory, with `vendor/` left out.
enum ProjectNavigatorListing {
    static func fileGroups(in files: [String: String]) -> [(directory: String, title: String, paths: [String])] {
        let own = files.keys.filter {
            !GoVendorWriter.isVendoredPath($0)
                && !$0.hasSuffix("/" + GopherForgeProject.folderMarker)
        }.sorted()
        let grouped = Dictionary(grouping: own) { path -> String in
            let components = path.split(separator: "/").dropLast()
            return components.joined(separator: "/")
        }
        var directories: Set<String> = [""]
        for path in files.keys where !GoVendorWriter.isVendoredPath(path) {
            let components = path.split(separator: "/").dropLast()
            guard !components.isEmpty else { continue }
            for count in 1...components.count {
                directories.insert(components.prefix(count).joined(separator: "/"))
            }
        }
        return directories.sorted().map { directory in
                (
                    directory: directory,
                    title: directory.isEmpty ? "Project files" : directory,
                    paths: (grouped[directory] ?? []).sorted()
                )
            }
    }
}
