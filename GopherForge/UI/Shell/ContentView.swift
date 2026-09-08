import SwiftUI

/// The shell: four sections in a tab bar, on both devices.
///
/// The workspace inside still adapts — iPad shows the file tree beside the
/// editor and a dock below it, iPhone stacks them — but which section you are
/// in is a shallow, four-way choice, and that is a tab bar's job on either
/// screen.
struct ContentView: View {
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
        // One layout, both devices.
        //
        // iPad had a split view whose sidebar held the same four sections the
        // phone puts in a tab bar. Pinned open it took a third of the width for
        // navigation nobody was looking at while coding, and collapsed it was a
        // button that did what the tab bar does — with the added cost that the
        // sidebar and the workspace's own file navigator are two drawers on the
        // same edge, and it was never obvious which one the leading button
        // meant. The sections are shallow and always four; a tab bar says that
        // and gets out of the way.
        tabLayout
            .tint(GopherForgeTheme.accent)
            .environment(workspace)
            .environment(navigation)
            .environment(learnProgress)
            .task { await workspace.prepare() }
            // Editor text lives in the model and is written back on a debounce,
            // and a debounce that has not fired does not survive the process
            // being suspended or killed — so leaving the foreground writes now.
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                Task { await workspace.flush() }
            }
    }

    private var tabLayout: some View {
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
        .tabViewStyle(.tabBarOnly)
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
