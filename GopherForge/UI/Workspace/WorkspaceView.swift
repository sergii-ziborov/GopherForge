import SwiftUI

/// Widths are measured inside the workspace, after the system has accounted
/// for window size and safe areas. The phone may switch among these layouts
/// while the same project remains open, including when a Duo is folded.
enum WorkspaceLayout: Equatable {
    case compact
    case columns
    case canvas
    case tablet

    static func resolve(width: CGFloat, isPad: Bool) -> Self {
        if isPad && width >= 800 { return .tablet }
        if width >= 900 { return .canvas }
        if width >= 600 { return .columns }
        return .compact
    }

    var hasNavigator: Bool { self != .compact }
    var showsDock: Bool { self == .canvas || self == .tablet }

    static func navigatorWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.22, 190), 260)
    }

    static func inspectorWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.30, 300), 420)
    }
}

/// The Build side.
///
/// The workspace follows the space available to its window. A closed phone
/// uses full-height tabs and a file drawer; an unfolded phone can keep its
/// file tree in view, then show code and a console side by side when wider.
/// The iPad keeps its familiar resizable dock below the editor.
struct WorkspaceView: View {
    @Environment(WorkspaceModel.self) var workspace
    @Environment(AppNavigation.self) var navigation
    @AppStorage("editorFontSize") var fontSize: Double = 14

    @State var pane: WorkspacePane = .code
    @State var dockPane: WorkspacePane = .problems
    @State var laptopPane: WorkspacePane = .code
    @State var laptopWorkPane: WorkspacePane = .code
    @State var laptopShowsFiles = false
    @State var laptopFocusGeneration = 0
    @State var laptopShouldFocus = false
    @State var keyboardVisible = false
    @State var laptopEditor: UITextView?
    @State var duoPartiallyOpen = false
    @State var usesLaptopLayout = ProcessInfo.processInfo.arguments.contains(
        "-GopherForgeDuoLaptopUITest"
    )
    @State var layout: WorkspaceLayout = .compact
    @State var terminal: ProjectTerminalSession?
    /// The dock's height on iPad, dragged at the seam and remembered. 280 fits
    /// a handful of diagnostics; someone reading a long test log wants more,
    /// someone writing wants the editor back, and neither should have to take
    /// whatever was chosen for them.
    @AppStorage("dockHeight") var dockHeight: Double = 280
    @State var dockDragStart: Double?
    let dockHeightRange: ClosedRange<Double> = 120...640
    @State var isDrawerOpen = false
    @State var isShowingPackages = false
    @State var libraryFolders: [String] = []
    @State var filingItem: ProjectLibraryItem?

    @ViewBuilder var body: some View {
        if #available(iOS 27.1, *) {
            workspaceRoot.onHingeChange { _, context in
                duoPartiallyOpen = context.hinge?.status == .partiallyOpen
            }
        } else {
            workspaceRoot
        }
    }

    var workspaceRoot: some View {
        VStack(spacing: 0) {
            WorkspaceStatusStrip(status: workspace.toolchain)
            if workspace.hasUnsavedChanges || workspace.saveError != nil {
                HStack(spacing: 8) {
                    Label(
                        workspace.saveError ?? "Сохранение…",
                        systemImage: workspace.saveError == nil ? "arrow.clockwise" : "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(workspace.saveError == nil ? Color.secondary : Color.red)
                    Spacer(minLength: 0)
                    if workspace.saveError != nil {
                        Button("Повторить") { Task { await workspace.retrySave() } }
                            .font(.caption)
                        if let project = workspace.recoveryProject ?? workspace.project {
                            ShareLink(
                                item: ProjectExport(project: project),
                                preview: SharePreview(project.name)
                            ) {
                                Text("Экспорт").font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            if let terminal {
                workspaceArea(terminal: terminal)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(usesLaptopLayout ? .keyboard : [], edges: .bottom)
        .navigationTitle(workspace.project?.name ?? "Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .toolbar(usesLaptopLayout ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $isShowingPackages) {
            NavigationStack {
                PackageBrowserView(allowsProjectChoice: false) {
                    isShowingPackages = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isShowingPackages = false }
                    }
                }
            }
        }
        .sheet(item: $filingItem) { item in
            ProjectOrganizerSheet(item: item, existingFolders: libraryFolders) { draft in
                Task { await applyFiling(draft) }
            }
        }
        .task {
            if terminal == nil { terminal = ProjectTerminalSession(workspace: workspace) }
        }
        .onChange(of: workspace.projectGeneration) {
            pane = .code
            dockPane = .problems
            laptopPane = .code
            laptopWorkPane = .code
            laptopShowsFiles = false
            laptopShouldFocus = false
            laptopEditor = nil
            isDrawerOpen = false
            terminal = ProjectTerminalSession(workspace: workspace)
            if usesLaptopLayout { scheduleInitialLaptopFocus() }
        }
        // A finished run opens the pane that answers it. Keyed on the
        // generation rather than the result, so running the same thing twice
        // still moves.
        .onChange(of: workspace.resultGeneration) {
            guard let result = workspace.lastResult,
                  let destination = WorkspacePane.afterRun(result)
            else {
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                if layout.showsDock {
                    dockPane = destination
                }
                selectLaptopPane(destination)
                pane = destination
            }
        }
        .onChange(of: workspace.runningPhase) {
            guard let phase = workspace.runningPhase,
                  let destination = WorkspacePane.afterStarting(phase)
            else {
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                if layout.showsDock {
                    dockPane = destination
                }
                selectLaptopPane(destination)
                pane = destination
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    // MARK: - Layouts

    var forceLaptopLayout: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-GopherForgeDuoLaptopUITest")
        #else
        false
        #endif
    }

    func activeDivisionFrame(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            geometry.reservedRegions(kind: .division)
                .map(\.frame)
                .first { $0.intersects(CGRect(origin: .zero, size: geometry.size)) }
        } else {
            nil
        }
    }

    /// Device Hub can report a half-open hinge without a division region.
    /// The window midpoint still marks the horizontal hinge in that posture.
    func fallbackLaptopDivision(in geometry: GeometryProxy) -> CGRect? {
        guard duoPartiallyOpen, geometry.size.height > geometry.size.width else { return nil }
        let hingeGlobalY = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .bounds.midY ?? geometry.frame(in: .global).midY
        let hingeY = hingeGlobalY - geometry.frame(in: .global).minY
        guard hingeY > 80, hingeY < geometry.size.height - 80 else { return nil }
        return CGRect(x: 0, y: hingeY, width: geometry.size.width, height: 12)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        if usesLaptopLayout {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    navigation.show(.projects)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Projects")
                    }
                }
                .accessibilityLabel("Back to Projects")
                .accessibilityIdentifier(AccessibilityID.laptopProjectsBack)
            }
        } else if !layout.hasNavigator {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen.toggle() }
                } label: {
                    Label("Files", systemImage: "sidebar.leading")
                }
                .accessibilityIdentifier(AccessibilityID.filesToggle)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            ForEach(WorkspaceToolbarActions.primaryPhases, id: \.self) { phase in
                PhaseButton(phase: phase)
            }
            Menu {
                Button {
                    Task { await openOrganizer() }
                } label: {
                    Label("Rename and file…", systemImage: "folder")
                }
                .accessibilityIdentifier(AccessibilityID.projectOrganize)
                if let project = workspace.project {
                    ShareLink(
                        item: ProjectExport(project: project),
                        preview: SharePreview(project.name)
                    ) {
                        Label("Export as .tar.gz", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier(AccessibilityID.exportProject)
                }
                Button {
                    isShowingPackages = true
                } label: {
                    Label("Add packages", systemImage: "shippingbox")
                }
                .accessibilityIdentifier(AccessibilityID.packagesEntry)
                Divider()
                Button {
                    Task { await workspace.run(.build) }
                } label: {
                    Label("Compile check", systemImage: "hammer")
                }
                .disabled(!workspace.canRun)
                .accessibilityIdentifier(AccessibilityID.phase(.build))
            } label: {
                Label("Project", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier(AccessibilityID.projectMenu)
        }
    }

    func openOrganizer() async {
        guard let id = workspace.projectID else { return }
        libraryFolders = (try? await ProjectLibrary.shared.folders()) ?? []
        if let item = try? await ProjectLibrary.shared.project(id: id) {
            filingItem = item
            return
        }
        if let project = workspace.project {
            filingItem = ProjectLibraryItem(
                id: id,
                project: project,
                lastOpenedAt: Date()
            )
        }
    }

    func applyFiling(_ draft: ProjectFilingDraft) async {
        guard let id = workspace.projectID else { return }
        _ = try? await ProjectLibrary.shared.update(
            id: id,
            name: draft.trimmedName,
            folder: draft.folder,
            tags: draft.tags,
            isFavorite: draft.isFavorite,
            summary: draft.summary
        )
        if let refreshed = try? await ProjectLibrary.shared.project(id: id) {
            workspace.refreshMetadata(from: refreshed)
        }
    }
}
