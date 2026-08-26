import SwiftUI

/// The adaptive shell.
///
/// iPad gets a sidebar because there is room for the project list and the
/// workspace at once; iPhone gets a tab bar because a sidebar there costs a
/// third of the screen for navigation nobody is looking at while they code.
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var workspace = WorkspaceModel()
    @State private var section: AppSection? = .projects

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(GopherForgeTheme.accent)
        .environment(workspace)
        .task { await workspace.prepare() }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(AppSection.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.systemImage)
                    }
                }
            }
            .navigationTitle("GopherForge")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                destination(for: section ?? .projects)
            }
        }
    }

    private var compactLayout: some View {
        TabView(selection: $section) {
            ForEach(AppSection.allCases) { item in
                NavigationStack {
                    destination(for: item)
                }
                .tabItem { Label(item.title, systemImage: item.systemImage) }
                .tag(AppSection?.some(item))
            }
        }
    }

    @ViewBuilder
    private func destination(for section: AppSection) -> some View {
        switch section {
        case .projects: ProjectsHomeView()
        case .build: WorkspaceView()
        case .learn: LearnHomeView()
        case .settings: SettingsView()
        }
    }
}
