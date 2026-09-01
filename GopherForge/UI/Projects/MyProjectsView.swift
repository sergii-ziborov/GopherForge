import SwiftUI

/// Every project the owner has: searched, filed and sorted.
///
/// The dashboard used to be the whole story, and it showed the ten most recent
/// projects in a flat list. That is a fine strip and a poor library: past ten
/// projects there was no way to find one by name, nothing to group them by, and
/// the eleventh quietly evicted the first. This screen is the library; the
/// dashboard keeps the strip and links here.
struct MyProjectsView: View {
    enum Sort: String, CaseIterable, Identifiable {
        case recentlyOpened
        case name
        case folder

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recentlyOpened: "Recently opened"
            case .name: "Name"
            case .folder: "Folder"
            }
        }
    }

    @State private var query = ""
    @State private var selectedFolder: String?
    @State private var favoritesOnly = false
    @State private var sort: Sort = .recentlyOpened
    @State private var organizing: ProjectLibraryItem?
    @State private var deletionCandidate: ProjectLibraryItem?

    let items: [ProjectLibraryItem]
    let onOpen: (ProjectLibraryItem) -> Void
    let onToggleFavorite: (ProjectLibraryItem) -> Void
    let onOrganize: (ProjectLibraryItem, ProjectFilingDraft) -> Void
    let onDelete: (ProjectLibraryItem) -> Void

    private var folders: [String] {
        Array(Set(items.map(\.folderLabel)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var results: [ProjectLibraryItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items
            .filter { item in
                if favoritesOnly, !item.favorite { return false }
                if let selectedFolder, item.folderLabel != selectedFolder { return false }
                return item.matches(needle)
            }
            .sorted(by: isOrdered)
    }

    private var grouped: [(folder: String, items: [ProjectLibraryItem])] {
        let groups = Dictionary(grouping: results, by: \.folderLabel)
        return groups.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No projects yet",
                    systemImage: "folder",
                    description: Text("Anything you create or import shows up here.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(grouped, id: \.folder) { group in
                    Section(header: folderHeader(group.folder, count: group.items.count)) {
                        ForEach(group.items) { item in
                            row(for: item)
                        }
                    }
                }
            }
        }
        .navigationTitle("My projects")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Name, folder, tag or file"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
        .safeAreaInset(edge: .top) { folderChips }
        .sheet(item: $organizing) { item in
            ProjectOrganizerSheet(item: item, existingFolders: folders) { draft in
                onOrganize(item, draft)
            }
        }
        .alert(
            "Remove \(deletionCandidate?.project.name ?? "this project")?",
            isPresented: Binding(
                get: { deletionCandidate != nil },
                set: { if !$0 { deletionCandidate = nil } }
            ),
            presenting: deletionCandidate
        ) { item in
            Button("Remove", role: .destructive) { onDelete(item) }
            Button("Keep", role: .cancel) {}
        } message: { _ in
            Text("This removes it from the library on this device. "
                + "Export it first if you want to keep a copy.")
        }
    }

    // MARK: - Pieces

    private var filterMenu: some View {
        Menu {
            Picker("Sort by", selection: $sort) {
                ForEach(Sort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            Toggle(isOn: $favoritesOnly) {
                Label("Starred only", systemImage: "star")
            }
        } label: {
            Label("Sort and filter", systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier(AccessibilityID.libraryFilter)
    }

    /// The folders, as something to tap. A picker would hide them behind a tap
    /// and a folder you cannot see is a folder you forget you made.
    @ViewBuilder
    private var folderChips: some View {
        if folders.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All", isSelected: selectedFolder == nil) {
                        selectedFolder = nil
                    }
                    ForEach(folders, id: \.self) { folder in
                        chip(title: folder, isSelected: selectedFolder == folder) {
                            selectedFolder = selectedFolder == folder ? nil : folder
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? GopherForgeTheme.accentSolid : GopherForgeTheme.accentWash(0.12),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : GopherForgeTheme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.libraryFolder(title))
    }

    private func folderHeader(_ folder: String, count: Int) -> some View {
        HStack {
            Label(folder, systemImage: folder == ProjectLibraryItem.looseFolder ? "tray" : "folder")
            Spacer()
            Text("\(count)").monospacedDigit()
        }
    }

    private func row(for item: ProjectLibraryItem) -> some View {
        Button {
            onOpen(item)
        } label: {
            ProjectLibraryRow(item: item)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.project(item.id))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deletionCandidate = item
            } label: {
                Label("Remove", systemImage: "trash")
            }
            Button {
                organizing = item
            } label: {
                Label("Organize", systemImage: "folder")
            }
            .tint(GopherForgeTheme.accentSolid)
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggleFavorite(item)
            } label: {
                Label(
                    item.favorite ? "Unstar" : "Star",
                    systemImage: item.favorite ? "star.slash" : "star"
                )
            }
            .tint(GopherForgeTheme.sun)
        }
        .contextMenu {
            Button {
                organizing = item
            } label: {
                Label("Rename and file…", systemImage: "folder")
            }
            .accessibilityIdentifier(AccessibilityID.projectOrganize)
            Button {
                onToggleFavorite(item)
            } label: {
                Label(item.favorite ? "Unstar" : "Star", systemImage: "star")
            }
            Button(role: .destructive) {
                deletionCandidate = item
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func isOrdered(_ left: ProjectLibraryItem, _ right: ProjectLibraryItem) -> Bool {
        // Starred first whatever the sort: a star is the owner saying "this one
        // matters", and a sort that buries it ignores them.
        if left.favorite != right.favorite { return left.favorite }
        switch sort {
        case .recentlyOpened:
            return left.lastOpenedAt > right.lastOpenedAt
        case .name, .folder:
            return left.project.name.localizedStandardCompare(right.project.name)
                == .orderedAscending
        }
    }
}
