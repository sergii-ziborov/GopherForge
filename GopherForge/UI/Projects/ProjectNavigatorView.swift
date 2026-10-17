import SwiftUI

/// The file navigator: a searchable tree that lives beside the editor rather
/// than on top of it.
///
/// It was a sheet, and a sheet is the wrong shape for this. Choosing a file is
/// not a decision you make once and dismiss — it is something you do while
/// reading code, and a sheet covers the code you were reading. Here it is a
/// column when the window is wide and a drawer when narrow, and either way the editor stays
/// where it was.
///
/// Vendored modules are packages, not folders. Expanding `vendor/gin-gonic`
/// into every file gin ships is how the tree stops being a map of *this*
/// project. Those rows live under Packages, where they can be added, searched
/// and removed.
struct ProjectNavigatorView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var query = ""
    /// Folders the reader opened besides the path of the file on screen.
    @State private var expandedFolders: Set<String> = []
    /// Folders on that path which the reader closed.
    @State private var collapsedFolders: Set<String> = []
    /// Package rows whose dependencies are showing.
    @State private var expandedPackages: Set<String> = []
    @State private var packageRemoval: GoPackageTree.Removal?
    /// Built off the redraw. Opening a folder only walks this, it does not
    /// scan the project again.
    @State private var fileNodes: [ProjectFileNode] = []
    @State private var packageNodes: [GoPackageTree.Node] = []
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
        .task(id: workspace.navigatorRevision) {
            await refreshNavigatorTrees()
        }
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
        .confirmationDialog(
            packageRemovalTitle,
            isPresented: Binding(
                get: { packageRemoval != nil },
                set: { if !$0 { packageRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove package", role: .destructive) {
                guard let packageRemoval else { return }
                workspace.removePackage(packageRemoval.root)
                self.packageRemoval = nil
            }
            if packageRemoval?.exclusiveDependents.isEmpty == false {
                Button("Remove package and dependencies", role: .destructive) {
                    guard let packageRemoval else { return }
                    workspace.removePackages(packageRemoval.all)
                    self.packageRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) { packageRemoval = nil }
        } message: {
            Text(packageRemovalMessage)
        }
    }

    private var packageRemovalTitle: String {
        let name = packageRemoval?.root.split(separator: "/").last.map(String.init) ?? "package"
        guard let count = packageRemoval?.exclusiveDependents.count, count > 0 else {
            return "Remove \(name)?"
        }
        return "Remove \(name) and \(count) \(count == 1 ? "dependency" : "dependencies") only it uses?"
    }

    private var packageRemovalMessage: String {
        guard let packageRemoval, !packageRemoval.exclusiveDependents.isEmpty else {
            return "This takes the package out of the project."
        }
        let names = packageRemoval.exclusiveDependents.map {
            $0.split(separator: "/").last.map(String.init) ?? $0
        }
        return "Also only used here: \(names.joined(separator: ", "))."
    }

    // MARK: - Tree

    private var tree: some View {
        List {
            Section {
                ForEach(rows) { row in
                    if row.isFolder {
                        folderRow(row)
                    } else {
                        fileRow(row)
                    }
                }
            } header: {
                Text("Project files")
            }
            packagesSection
        }
        .listStyle(.sidebar)
        .onChange(of: workspace.selectedFile) { _, path in
            for folder in ProjectNavigatorListing.ancestors(of: path) {
                collapsedFolders.remove(folder)
            }
        }
    }

    private func folderIsOpen(_ path: String) -> Bool {
        ProjectNavigatorListing.isOpen(
            path,
            revealing: workspace.selectedFile,
            expanded: expandedFolders,
            collapsed: collapsedFolders
        )
    }

    private func toggleFolder(_ path: String) {
        if folderIsOpen(path) {
            expandedFolders.remove(path)
            collapsedFolders.insert(path)
        } else {
            collapsedFolders.remove(path)
            expandedFolders.insert(path)
        }
    }

    private func folderRow(_ row: ProjectNavigatorRow) -> some View {
        HStack(spacing: 8) {
            Button {
                toggleFolder(row.path)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: folderIsOpen(row.path) ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, alignment: .center)
                    Image(systemName: "folder")
                        .font(.callout)
                        .frame(width: 20, alignment: .center)
                    Text(row.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(row.name), \(folderIsOpen(row.path) ? "expanded" : "collapsed")")
            Menu {
                Button { beginCreating(.file, in: row.path) } label: {
                    Label("New file here", systemImage: "doc.badge.plus")
                }
                Button { beginCreating(.folder, in: row.path) } label: {
                    Label("New subfolder", systemImage: "folder.badge.plus")
                }
                Divider()
                Button { beginRenaming(.init(path: row.path, isFolder: true)) } label: {
                    Label("Rename folder", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleting = .init(path: row.path, isFolder: true)
                } label: {
                    Label("Delete folder", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Folder actions for \(row.path)")
        }
        .padding(.leading, CGFloat(row.depth) * 14)
        .textCase(nil)
    }

    private func fileRow(_ row: ProjectNavigatorRow) -> some View {
        Button {
            open(row.path, at: nil)
        } label: {
            ProjectFileRow(
                path: row.path,
                isSelected: workspace.selectedFile == row.path,
                detail: nil
            )
        }
        .buttonStyle(.plain)
        .padding(.leading, CGFloat(row.depth) * 14)
        .accessibilityIdentifier(AccessibilityID.file(row.path))
        .contextMenu {
            Button { beginRenaming(.init(path: row.path, isFolder: false)) } label: {
                Label("Rename file", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleting = .init(path: row.path, isFolder: false)
            } label: {
                Label("Delete file", systemImage: "trash")
            }
        }
    }

    private var packagesSection: some View {
        Section {
            Button {
                openPackageBrowser()
            } label: {
                Label("Add package", systemImage: "plus")
            }
            .accessibilityIdentifier(AccessibilityID.addPackage)

            ForEach(packageRows) { row in
                packageRow(row)
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

    private func packageRow(_ row: GoPackageTree.Row) -> some View {
        HStack(spacing: 6) {
            if row.hasChildren {
                Button {
                    if expandedPackages.contains(row.module.path) {
                        expandedPackages.remove(row.module.path)
                    } else {
                        expandedPackages.insert(row.module.path)
                    }
                } label: {
                    Image(systemName: expandedPackages.contains(row.module.path) ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    expandedPackages.contains(row.module.path)
                        ? "Collapse \(row.module.displayName)"
                        : "Expand \(row.module.displayName)"
                )
            } else {
                Color.clear.frame(width: 12, height: 1)
            }
            InstalledPackageRow(module: row.module)
        }
        .padding(.leading, CGFloat(row.depth) * 14)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                askToRemove(row.module.path)
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .accessibilityIdentifier(AccessibilityID.packageRemove)
        }
        .contextMenu {
            Button(role: .destructive) {
                askToRemove(row.module.path)
            } label: {
                Label("Remove \(row.module.displayName)", systemImage: "trash")
            }
        }
    }

    private func askToRemove(_ path: String) {
        let removal = GoPackageTree.removal(of: path, in: workspace.project?.files ?? [:])
        if removal.exclusiveDependents.isEmpty {
            workspace.removePackage(path)
        } else {
            packageRemoval = removal
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
                                SearchLineRow(
                                    line: line, query: query,
                                    fileKind: SourceFileKind.of(path: result.path)
                                )
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

    private var packageRows: [GoPackageTree.Row] {
        GoPackageTree.rows(of: packageNodes, expanded: expandedPackages)
    }

    private func refreshNavigatorTrees() async {
        let files = workspace.project?.files ?? [:]
        let revision = workspace.navigatorRevision
        async let tree = Task.detached(priority: .userInitiated) {
            ProjectNavigatorListing.tree(in: files)
        }.value
        async let packages = Task.detached(priority: .utility) {
            GoPackageTree.nodes(in: files)
        }.value
        let built = await (tree, packages)
        guard workspace.navigatorRevision == revision else { return }
        fileNodes = built.0
        packageNodes = built.1
    }

    private var matchingPackages: [GoVendorWriter.InstalledModule] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return packages.filter {
            $0.path.lowercased().contains(needle) || $0.displayName.lowercased().contains(needle)
        }
    }

    private var rows: [ProjectNavigatorRow] {
        ProjectNavigatorListing.rows(
            of: fileNodes,
            revealing: workspace.selectedFile,
            expanded: expandedFolders,
            collapsed: collapsedFolders
        )
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

