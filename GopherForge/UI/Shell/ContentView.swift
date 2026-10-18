import SwiftUI

/// The shell: four sections in a tab bar, on both devices.
///
/// The workspace inside adapts to the available width, including a folding
/// phone's changing display. Which section you are
/// in is a shallow, four-way choice, and that is a tab bar's job on either
/// screen.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var workspace = WorkspaceModel()
    @State private var navigation = AppNavigation()
    @State private var duoPresentation = DuoPresentation()
    /// Above the navigation stacks on purpose. A pushed screen inherits the
    /// environment of the stack that presents it, so progress owned inside the
    /// course screen would not reach the unit and lesson screens pushed from
    /// it — which is how a lesson could be marked complete and the course show
    /// nothing.
    @State private var learnProgress = LearnProgress()
    @AppStorage("keepAwakeDuringBuilds") private var keepAwake = false
    @AppStorage(AppLock.storageKey) private var requireFaceID = false
    @State private var isLocked = false
    @State private var shareStatus: String?
    @State private var isImportingShare = false
    @State private var importedShareKeys: Set<String> = []

    @ViewBuilder var body: some View {
        if #available(iOS 27.1, *) {
            shell.onHingeChange { _, context in
                if let hinge = context.hinge {
                    // Keyboard and section transitions can momentarily have
                    // no hinge context. Hardware capability stays stable,
                    // preserving the workspace and its open Files drawer.
                    duoPresentation = DuoPresentation(
                        isDuo: true, isPartiallyOpen: hinge.status == .partiallyOpen
                    )
                }
            }
        } else {
            shell
        }
    }

    private var shell: some View {
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
            .environment(\.duoPresentation, duoPresentation)
            .task {
                await workspace.prepare()
                #if DEBUG
                workspace.showDownloadLayoutFixtureIfRequested()
                #endif
            }
            .onChange(of: keepAwake, initial: true) { _, _ in updateIdleTimer() }
            .onChange(of: workspace.isRunning) { _, _ in updateIdleTimer() }
            .onChange(of: workspace.downloadProgress?.status) { _, _ in updateIdleTimer() }
            .overlay {
                if isLocked {
                    AppLockCover(unlock: unlock)
                }
            }
            .onOpenURL { url in
                Task { await consumeSharedImports(opened: url) }
            }
            .sheet(isPresented: Binding(
                get: { workspace.showsDownloadSheet },
                set: { showing in
                    if !showing { workspace.hideDownloadSheet() }
                }
            )) {
                ModuleDownloadSheet()
                    .environment(workspace)
            }
            .overlay(alignment: .bottom) {
                if let progress = workspace.downloadProgress, !workspace.showsDownloadSheet,
                   !usesInlineDownloadStatus {
                    Button {
                        workspace.showDownloadSheet()
                    } label: {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(progress.status)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(progress.alreadyInstalled.count + progress.installed.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 64)
                    .accessibilityIdentifier("download.banner")
                }
            }
            .overlay(alignment: .top) {
                if let shareStatus {
                    Text(shareStatus)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                        .accessibilityIdentifier("share.import.status")
                }
            }
            // Editor text lives in the model and is written back on a debounce,
            // and a debounce that has not fired does not survive the process
            // being suspended or killed — so leaving the foreground writes now.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    workspace.interruptStalledDownload()
                    if isLocked { Task { await unlock() } }
                    Task { await consumeSharedImports(opened: nil) }
                } else {
                    if phase == .background, requireFaceID { isLocked = true }
                    updateIdleTimer()
                    Task { await workspace.flush() }
                }
            }
    }

    private var usesInlineDownloadStatus: Bool {
        guard navigation.section == .build else { return false }
        if UIDevice.current.userInterfaceIdiom == .pad { return true }
        return !duoPresentation.isDuo && UIDevice.current.userInterfaceIdiom == .phone
            && verticalSizeClass == .compact
    }

    private func updateIdleTimer() {
        let busy = workspace.isRunning || workspace.downloadProgress != nil
        UIApplication.shared.isIdleTimerDisabled = keepAwake && busy
    }

    private func unlock() async {
        guard requireFaceID else {
            isLocked = false
            return
        }
        if await AppLock.authenticate() {
            isLocked = false
        }
    }

    /// A GitHub link shared into the app is downloaded, including the modules
    /// `go.mod` requires, and opened. The share extension can only queue and
    /// foreground; this is the step that turns the link into a project.
    private func consumeSharedImports(opened url: URL?) async {
        guard !isImportingShare else { return }
        isImportingShare = true
        defer { isImportingShare = false }
        var raws: [String] = []
        if let url, let raw = GopherForgeLink.repositoryURL(from: url) {
            raws.append(raw)
        }
        while let queued = SharedImportQueue.dequeue() {
            raws.append(queued)
        }
        let pending = raws.compactMap { raw -> (key: String, reference: GitHubRepositoryReference)? in
            guard let reference = try? GitHubRepositoryReference.parse(raw) else { return nil }
            return (reference.displayName, reference)
        }.filter { importedShareKeys.insert($0.key).inserted }
        guard !pending.isEmpty else { return }

        for item in pending {
            shareStatus = nil
            do {
                let project = try await workspace.importGitHub(item.reference)
                if workspace.open(project) {
                    navigation.show(.build)
                    shareStatus = nil
                } else {
                    shareStatus = "\(item.reference.displayName) was downloaded, but the open project could not be replaced."
                }
            } catch {
                importedShareKeys.remove(item.key)
                shareStatus = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private var usesLandscapeNavigation: Bool {
        !duoPresentation.isDuo && UIDevice.current.userInterfaceIdiom == .phone
            && verticalSizeClass == .compact
    }

    @ViewBuilder
    private var tabLayout: some View {
        if duoPresentation.isDuo {
            nativeTabs
        } else {
            nativeTabs
                .toolbar(usesLandscapeNavigation ? .hidden : .automatic, for: .tabBar)
                .overlay(alignment: .trailing) {
                    if usesLandscapeNavigation { LandscapeSectionRail() }
                }
        }
    }

    private var nativeTabs: some View {
        TabView(selection: tabSelection) {
            ForEach(AppSection.allCases) { item in
                Group {
                    if item == .build && duoPresentation.isDuo {
                        // Duo owns its compact header. Keeping an invisible
                        // navigation toolbar above it intercepts header taps.
                        destination(for: item)
                    } else {
                        NavigationStack { destination(for: item) }
                            .accessibilityIdentifier(AccessibilityID.section(item))
                    }
                }
                .tabItem { Label(item.title, systemImage: item.systemImage) }
                .tag(item)
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

/// Conventional phone landscape navigation floats at the trailing edge.
/// The scrollable column still fits when the software keyboard is visible.
struct LandscapeSectionRail: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(AppSection.allCases) { section in
                        Button { navigation.show(section) } label: {
                            VStack(spacing: 2) {
                                Image(systemName: section.systemImage).font(.system(size: 19))
                                Text(section.title).font(.system(size: 9, weight: .medium))
                            }
                            .frame(width: 50, height: 44)
                            .background(navigation.section == section ? GopherForgeTheme.accent.opacity(0.16) : .clear,
                                        in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(navigation.section == section ? GopherForgeTheme.accent : Color(uiColor: .label))
                        .accessibilityLabel(section.title)
                        .accessibilityIdentifier("landscape.section.\(section.rawValue)")
                        .accessibilityAddTraits(navigation.section == section ? .isSelected : [])
                    }
                }
                .padding(5)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: 60, height: min(geometry.size.height, 198))
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 72)
    }
}

struct ModuleDownloadStatusButton: View {
    @Environment(WorkspaceModel.self) private var workspace
    let progress: ModuleDownload
    var compact = false

    var body: some View {
        Button {
            workspace.showDownloadSheet()
        } label: {
            HStack(spacing: 8) {
                ProgressView().controlSize(compact ? .mini : .regular)
                Text(progress.status).font(.caption).lineLimit(1)
                Spacer(minLength: 0)
                Text("\(progress.alreadyInstalled.count + progress.installed.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 4 : 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: compact ? 0 : 40))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("download.banner")
    }
}
