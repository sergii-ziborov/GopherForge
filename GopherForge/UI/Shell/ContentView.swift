import SwiftUI

/// The adaptive shell.
///
/// iPad gets a sidebar because there is room for the project list and the
/// workspace at once; iPhone gets a tab bar because a sidebar there costs a
/// third of the screen for navigation nobody is looking at while they code.
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var workspace = WorkspaceModel()
    @State private var navigation = AppNavigation()
    /// Above the navigation stacks on purpose. A pushed screen inherits the
    /// environment of the stack that presents it, so progress owned inside the
    /// course screen would not reach the unit and lesson screens pushed from
    /// it — which is how a lesson could be marked complete and the course show
    /// nothing.
    @State private var learnProgress = LearnProgress()

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
        .environment(navigation)
        .environment(learnProgress)
        .task { await workspace.prepare() }
        // The last chance to keep what is in the editor. Autosave debounces,
        // and a debounce that has not fired does not survive the process being
        // suspended or killed — so leaving the foreground writes now.
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await workspace.flush() }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(AppSection.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.systemImage)
                    }
                    .accessibilityIdentifier(AccessibilityID.section(item))
                }
            }
            .navigationTitle("GopherForge")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                destination(for: navigation.section)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(AppSection.allCases) { item in
                NavigationStack {
                    destination(for: item)
                }
                .tabItem { Label(item.title, systemImage: item.systemImage) }
                .tag(item)
                .accessibilityIdentifier(AccessibilityID.section(item))
            }
        }
    }

    /// The sidebar's selection is optional because a split view can have
    /// none; the app always has a section, so the two are bridged here rather
    /// than making every screen deal with nil.
    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { navigation.section },
            set: { if let value = $0 { navigation.section = value } }
        )
    }

    private var tabSelection: Binding<AppSection> {
        Binding(
            get: { navigation.section },
            set: { navigation.section = $0 }
        )
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
