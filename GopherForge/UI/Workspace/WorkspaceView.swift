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
    @Environment(WorkspaceModel.self) private var workspace
    @AppStorage("editorFontSize") private var fontSize: Double = 14

    @State private var pane: WorkspacePane = .code
    @State private var dockPane: WorkspacePane = .problems
    @State private var laptopPane: WorkspacePane = .terminal
    @State private var laptopShowsFiles = false
    @State private var layout: WorkspaceLayout = .compact
    @State private var terminal: ProjectTerminalSession?
    /// The dock's height on iPad, dragged at the seam and remembered. 280 fits
    /// a handful of diagnostics; someone reading a long test log wants more,
    /// someone writing wants the editor back, and neither should have to take
    /// whatever was chosen for them.
    @AppStorage("dockHeight") private var dockHeight: Double = 280
    @State private var dockDragStart: Double?
    private let dockHeightRange: ClosedRange<Double> = 120...640
    @State private var isDrawerOpen = false
    @State private var isShowingPackages = false
    @State private var libraryFolders: [String] = []
    @State private var filingItem: ProjectLibraryItem?

    var body: some View {
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
                GeometryReader { geometry in
                    let availableLayout = WorkspaceLayout.resolve(
                        width: geometry.size.width,
                        isPad: UIDevice.current.userInterfaceIdiom == .pad
                    )
                    Group {
                        if #available(iOS 27.1, *),
                           availableLayout != .compact,
                           !geometry.reservedRegions(kind: .division).isEmpty {
                            foldedLayout(
                                terminal: terminal,
                                layout: availableLayout,
                                isLaptop: geometry.size.height > geometry.size.width
                            )
                        } else {
                            switch availableLayout {
                            case .compact:
                                compactLayout(terminal: terminal)
                            case .columns:
                                columnsLayout(terminal: terminal, width: geometry.size.width)
                            case .canvas:
                                canvasLayout(terminal: terminal, width: geometry.size.width)
                            case .tablet:
                                tabletLayout(terminal: terminal, width: geometry.size.width)
                            }
                        }
                    }
                    .onAppear { adoptLayout(availableLayout) }
                    .onChange(of: availableLayout) { _, newValue in adoptLayout(newValue) }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(workspace.project?.name ?? "Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
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
            laptopPane = .terminal
            laptopShowsFiles = false
            isDrawerOpen = false
            terminal = ProjectTerminalSession(workspace: workspace)
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
                laptopPane = destination
                laptopShowsFiles = false
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
                laptopPane = destination
                laptopShowsFiles = false
                pane = destination
            }
        }
    }

    // MARK: - Layouts

    private func adoptLayout(_ newLayout: WorkspaceLayout) {
        guard layout != newLayout else { return }
        if newLayout.showsDock && !layout.showsDock && pane != .code {
            dockPane = pane
        }
        if newLayout.hasNavigator { isDrawerOpen = false }
        layout = newLayout
    }

    /// The unfolded portrait display can keep Files visible, while each work
    /// pane still gets the full height. This is the same central-tab pattern
    /// used by Crabrix, rather than a shallow editor over a shallow terminal.
    private func columnsLayout(terminal: ProjectTerminalSession, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ProjectNavigatorView(onOpenFile: revealCode)
                .frame(width: WorkspaceLayout.navigatorWidth(for: width))
            Divider()
            paneStack(terminal: terminal)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
    }

    /// On the broad inner display, code and the selected result or terminal
    /// remain visible at the same time. Both side panels shrink with the
    /// window, leaving a useful minimum width for the editor.
    private func canvasLayout(terminal: ProjectTerminalSession, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ProjectNavigatorView(onOpenFile: revealCode)
                .frame(width: WorkspaceLayout.navigatorWidth(for: width))
            Divider()
            WorkspacePaneContent(pane: .code, terminal: terminal, fontSize: fontSize)
                .frame(minWidth: 0, maxWidth: .infinity)
            Divider()
            dockContent(terminal: terminal)
                .frame(width: WorkspaceLayout.inspectorWidth(for: width))
        }
    }

    /// When the inner display is partly folded, its center becomes a reserved
    /// region. ArrangementView places each side around that region instead of
    /// allowing a code line or a terminal control to cross the hinge.
    @available(iOS 27.1, *)
    private func foldedLayout(
        terminal: ProjectTerminalSession,
        layout: WorkspaceLayout,
        isLaptop: Bool
    ) -> some View {
        ArrangementView {
            Group {
                if isLaptop || layout.showsDock {
                    WorkspacePaneContent(pane: .code, terminal: terminal, fontSize: fontSize)
                } else {
                    paneStack(terminal: terminal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } secondary: {
            Group {
                if isLaptop {
                    laptopPanel(terminal: terminal)
                } else {
                    VStack(spacing: 0) {
                        ProjectNavigatorView(onOpenFile: revealCode)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if layout.showsDock {
                            Divider()
                            dockContent(terminal: terminal)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        // Let the arrangement follow the hinge in both orientations. Limiting
        // it to the horizontal axis hid the secondary pane in laptop posture.
        .arrangementViewStyle(.split)
    }

    /// With the hinge horizontal, keep code above it and the active console or
    /// result below it. Files remain one tap away in the lower pane.
    private func laptopPanel(terminal: ProjectTerminalSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    laptopShowsFiles = true
                } label: {
                    Label("Files", systemImage: "folder")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Files")
                .accessibilityIdentifier("laptop.files")
                Divider().frame(height: 24)
                WorkspacePanePicker(
                    selection: Binding(
                        get: { laptopPane },
                        set: { laptopPane = $0; laptopShowsFiles = false }
                    ),
                    panes: WorkspacePane.dockPanes
                )
            }
            .background(Color(.secondarySystemBackground))
            Divider()
            if laptopShowsFiles {
                ProjectNavigatorView(onOpenFile: {
                    laptopShowsFiles = false
                    revealCode()
                })
            } else {
                WorkspacePaneContent(
                    pane: laptopPane,
                    terminal: terminal,
                    fontSize: fontSize
                )
            }
        }
    }

    private func tabletLayout(terminal: ProjectTerminalSession, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ProjectNavigatorView(onOpenFile: revealCode)
                    .frame(width: WorkspaceLayout.navigatorWidth(for: width))
                Divider()
                WorkspacePaneContent(pane: .code, terminal: terminal, fontSize: fontSize)
            }

            dockResizeHandle
            dockContent(terminal: terminal)
            .frame(height: dockHeight)
        }
    }

    private func dockContent(terminal: ProjectTerminalSession) -> some View {
        VStack(spacing: 0) {
            WorkspacePanePicker(selection: dockSelection, panes: WorkspacePane.dockPanes)
            Divider()
            WorkspacePaneContent(pane: dockPane, terminal: terminal, fontSize: fontSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(.secondarySystemBackground))
    }

    /// Remember the last panel chosen beside the editor, so folding into a
    /// single work area keeps the terminal or result the person was reading.
    private var dockSelection: Binding<WorkspacePane> {
        Binding(
            get: { dockPane },
            set: { destination in
                dockPane = destination
                pane = destination
            }
        )
    }

    /// The drawer, over the editor rather than instead of it.
    ///
    /// A sheet covered the code someone was reading in order to let them choose
    /// what to read. This keeps the editor on screen behind it, and a tap on
    /// the dimmed part puts it away — which is what everything else on the
    /// phone does.
    private func compactLayout(terminal: ProjectTerminalSession) -> some View {
        ZStack(alignment: .leading) {
            LeadingEdgeOpenGesture {
                withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            paneStack(terminal: terminal)
                .simultaneousGesture(filesOpenSwipe)

            if isDrawerOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen = false } }
                    .accessibilityLabel("Close files")
                    .accessibilityAddTraits(.isButton)

                ProjectNavigatorView(
                    onSelect: { withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen = false } },
                    onOpenFile: revealCode
                )
                    .frame(maxWidth: 320)
                    .shadow(radius: 12)
                    .transition(.move(edge: .leading))
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onEnded { value in
                                if FilesDrawerGesture.shouldClose(translation: value.translation) {
                                    withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen = false }
                                }
                            }
                    )
            }
        }
    }

    /// A left-to-right flick that starts on the leading side, not only the
    /// Files button. Vertical editor scrolls are ignored.
    private var filesOpenSwipe: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                if FilesDrawerGesture.shouldOpen(
                    startX: value.startLocation.x,
                    translation: value.translation
                ) {
                    withAnimation(.easeOut(duration: 0.2)) { isDrawerOpen = true }
                }
            }
    }

    /// A file chosen in the tree is a request to read it. In a single work
    /// pane, the terminal (or any other pane) would otherwise hide the editor.
    private func revealCode() {
        withAnimation(.easeOut(duration: 0.2)) {
            pane = WorkspacePane.afterSelectingFile()
        }
    }

    /// The seam between editor and dock. Dragging it up gives the dock room,
    /// dragging it down gives it back to the code; the grabber says it moves.
    private var dockResizeHandle: some View {
        ZStack {
            Divider()
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 44, height: 5)
        }
        .frame(height: 14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .contentShape(Rectangle())
        // High priority: the seam sits between a text view and a list, both
        // of which scroll, and a drag that starts on it belongs to it.
        // Global coordinates, and that is the whole fix for a seam that moved
        // half as far as the finger. A drag gesture measures translation in
        // its own view's space by default, and this view moves with the drag:
        // every point the dock grows lifts the handle a point, so the finger
        // appears to have travelled only the difference. Measured against the
        // screen, the translation is the finger's.
        .highPriorityGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    if dockDragStart == nil { dockDragStart = dockHeight }
                    // Dragging up (negative translation) makes the dock taller.
                    let proposed = (dockDragStart ?? dockHeight) - value.translation.height
                    dockHeight = min(max(proposed, dockHeightRange.lowerBound), dockHeightRange.upperBound)
                }
                .onEnded { _ in dockDragStart = nil }
        )
        .accessibilityIdentifier(AccessibilityID.dockResizeHandle)
        .accessibilityLabel("Resize dock")
        .accessibilityValue("\(Int(dockHeight.rounded())) points")
        .accessibilityAdjustableAction { direction in
            let step: Double = 40
            switch direction {
            case .increment: dockHeight = min(dockHeight + step, dockHeightRange.upperBound)
            case .decrement: dockHeight = max(dockHeight - step, dockHeightRange.lowerBound)
            @unknown default: break
            }
        }
    }

    private func paneStack(terminal: ProjectTerminalSession) -> some View {
        VStack(spacing: 0) {
            // The switcher sits at the top: the keyboard owns the bottom of
            // the screen. It scrolls because six readable tabs need more room
            // than the narrowest window provides.
            WorkspacePanePicker(selection: $pane, panes: WorkspacePane.workPanes)
                .background(Color(.secondarySystemBackground))

            Divider()

            WorkspacePaneContent(
                pane: pane,
                terminal: terminal,
                fontSize: fontSize,
                onRevealCode: { withAnimation(.easeOut(duration: 0.2)) { pane = .code } }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !layout.hasNavigator {
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

    private func openOrganizer() async {
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

    private func applyFiling(_ draft: ProjectFilingDraft) async {
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

/// One phase button, so the toolbar cannot drift from what the model supports.
private struct PhaseButton: View {
    // Format is last, and the order is not cosmetic. On an 11-inch iPad the
    // top tab bar shares the row with these, four do not fit, and SwiftUI
    // folds the tail of the group into a "…" menu. With Format first, what
    // folded away was Test and Run — the two actions the app exists for. Now
    // the one that folds on a narrow iPad is Format, still one tap away in
    // the menu; on every wider screen all four show.
    //
    // gofmt itself is bundled and was wired to a phase from the start; until
    // now nothing on screen could invoke it — a working formatter with no
    // button.
    static let primaryPhases: [CompilationResult.Phase] = WorkspaceToolbarActions.primaryPhases

    @Environment(WorkspaceModel.self) private var workspace
    let phase: CompilationResult.Phase

    var body: some View {
        Button {
            Task { await workspace.run(phase) }
        } label: {
            if workspace.runningPhase == phase {
                ProgressView()
            } else {
                Label(
                    GopherForgeTheme.label(for: phase),
                    systemImage: GopherForgeTheme.systemImage(for: phase)
                )
            }
        }
        .disabled(!workspace.canRun)
        .accessibilityIdentifier(AccessibilityID.phase(phase))
    }
}

/// The strip above the editor, which is usually nothing at all.
///
/// A working compiler is not news. Saying "Bundled Go 1.27.1" on every screen
/// spends a line of a phone's height on a fact that does not change and that
/// Settings already reports. So this appears only when it has something to
/// say: that no compiler is staged, which is the only explanation for the
/// disabled buttons, or that a build is running, which is the difference
/// between working and stuck.
private struct WorkspaceStatusStrip: View {
    let status: ToolchainStatus

    var body: some View {
        if !status.isReady {
            MissingToolchainRow(status: status)
                .background(.bar)
                .accessibilityIdentifier(AccessibilityID.toolchainBanner)
        }
    }
}

/// Why every build action is unavailable, in the toolchain's own words.
private struct MissingToolchainRow: View {
    let status: ToolchainStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(GopherForgeTheme.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text(status.label).font(.footnote.weight(.medium))
                Text(status.detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
