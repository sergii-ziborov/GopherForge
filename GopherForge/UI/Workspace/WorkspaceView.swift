import SwiftUI
import GameController

struct DuoPresentation: Equatable {
    var isDuo = false
    var isPartiallyOpen = false
}

private struct DuoPresentationKey: EnvironmentKey {
    static let defaultValue = DuoPresentation()
}

extension EnvironmentValues {
    var duoPresentation: DuoPresentation {
        get { self[DuoPresentationKey.self] }
        set { self[DuoPresentationKey.self] = newValue }
    }
}

/// Widths are measured inside the workspace, after the system has accounted
/// for window size and safe areas. The phone may switch among these layouts
/// while the same project remains open, including when a Duo is folded.
enum WorkspaceLayout: Equatable {
    case compact
    case columns
    case canvas
    case tablet

    static func resolve(width: CGFloat, isPad: Bool, allowsCanvas: Bool = true) -> Self {
        if isPad && width >= 800 { return .tablet }
        if allowsCanvas && width >= 900 { return .canvas }
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

    static func tabletDockHeight(preferred: CGFloat, availableHeight: CGFloat) -> CGFloat {
        // A saved tall dock must leave room to edit after rotation or when
        // the keyboard reduces the viewport. Keep the saved preference intact.
        min(preferred, max(52, availableHeight - 240))
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
    @Environment(\.duoPresentation) private var duoPresentation
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("editorFontSize") var fontSize: Double = 14

    @State var pane: WorkspacePane = .code
    @State var dockPane: WorkspacePane = .problems
    @State var laptopPane: WorkspacePane = .code
    @State var laptopWorkPane: WorkspacePane = .code
    @State var laptopFocusGeneration = 0
    @State var laptopShouldFocus = false
    @State var keyboardVisible = false
    @State var keyboardFrame = CGRect.null
    @State var keyboardAccessoryEnabled = GCKeyboard.coalesced == nil
    @State var laptopEditor: UITextView?
    var duoPartiallyOpen: Bool { duoPresentation.isPartiallyOpen }
    var duoHingePresent: Bool { duoPresentation.isDuo }
    var isCompactPhoneLandscape: Bool {
        !duoHingePresent && UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact
    }
    var isClosedDuoLandscape: Bool {
        guard duoHingePresent, let bounds = activeWorkspaceWindow?.bounds else { return false }
        return bounds.width > bounds.height && bounds.height < 500
    }
    @AppStorage("workspaceNavigatorWidth") var navigatorWidth: Double = 220
    @AppStorage("workspaceNavigatorCollapsed") var navigatorCollapsed = false
    @State var navigatorDragStart: Double?
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
    @State var isShowingImportDetails = false
    @State var libraryFolders: [String] = []
    @State var filingItem: ProjectLibraryItem?

    @ViewBuilder var body: some View {
        if duoHingePresent {
            workspaceRoot
        } else {
            workspaceRoot
                .navigationTitle(workspace.project?.name ?? "Workspace")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(isCompactPhoneLandscape ? .hidden : .visible, for: .navigationBar)
                .toolbar { if !isCompactPhoneLandscape { toolbar } }
        }
    }

    var workspaceRoot: some View {
        VStack(spacing: 0) {
            if duoHingePresent { duoWorkspaceHeader }
            else if isCompactPhoneLandscape { phoneLandscapeHeader }
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

            // The initial library read can finish after the shell appears.
            // Do not offer pane controls before open() establishes the project:
            // its projectGeneration reset would otherwise undo an early tap.
            if let terminal, workspace.project != nil {
                workspaceArea(terminal: terminal)
                    .ignoresSafeArea(isCompactPhoneLandscape ? .container : [], edges: .trailing)
            } else if let error = workspace.saveError {
                ContentUnavailableView("Project unavailable", systemImage: "folder.badge.questionmark", description: Text(error))
            } else {
                ProgressView("Opening project…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("workspace.openingProject")
            }
            if isCompactPhoneLandscape || UIDevice.current.userInterfaceIdiom == .pad,
               let progress = workspace.downloadProgress, !workspace.showsDownloadSheet {
                ModuleDownloadStatusButton(progress: progress, compact: true)
            }
        }
        // The keyboard's actual frame owns this boundary. SwiftUI can retain
        // the previous responder's accessory height when Terminal becomes Code.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("Conflicting versions kept", isPresented: Binding(
            get: { workspace.persistenceNotice != nil },
            set: { if !$0 { workspace.persistenceNotice = nil } }
        )) {
            Button("OK") { workspace.persistenceNotice = nil }
        } message: {
            Text(workspace.persistenceNotice ?? "")
        }
        .ignoresSafeArea(duoHingePresent ? .container : [], edges: .top)
        .ignoresSafeArea((duoHingePresent && usesLaptopLayout || isCompactPhoneLandscape || isClosedDuoLandscape) && !softwareKeyboardVisible ? .container : [], edges: .bottom)
        .environment(\.softwareKeyboardAccessoryEnabled, keyboardAccessoryEnabled)
        .background(Color(pane == .code ? .systemBackground : .secondarySystemBackground).ignoresSafeArea(.container))
        .toolbar(usesLaptopLayout || keyboardVisible || isCompactPhoneLandscape ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $isShowingImportDetails) {
            if let project = workspace.project { ProjectImportDetailsView(project: project) }
        }
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
        .onChange(of: workspace.debugger.state) {
            guard workspace.debugger.state == .paused else { return }
            if layout.showsDock { dockPane = .code }
            selectLaptopPane(.code)
            pane = .code
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
            updateKeyboardFrame($0)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            updateKeyboardFrame(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { notification in
            if duoHingePresent {
                keyboardVisible = keyboardIntersectsWindow
            } else {
                updateKeyboardFrame(notification)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) {
            if !duoHingePresent { updateKeyboardFrame($0) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            // Some keyboards retain the accessory's old on-screen rectangle
            // in frameEnd while dismissing. A subsequent WillShow owns a new
            // responder; otherwise hiding must restore the section bar.
            keyboardFrame = .null
            keyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            keyboardVisible = keyboardIntersectsWindow
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)) { _ in
            keyboardAccessoryEnabled = softwareKeyboardVisible
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect)) { _ in
            keyboardAccessoryEnabled = true
        }
    }

    func updateKeyboardFrame(_ notification: Notification) {
        guard let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let window = activeWorkspaceWindow
        keyboardFrame = window.map { $0.convert(frame, from: $0.screen.coordinateSpace) } ?? frame
        keyboardVisible = keyboardIntersectsWindow
        if keyboardVisible {
            // The hardware-keyboard shelf is only the accessory's height.
            // A software keyboard includes its rows of keys. Off-screen and
            // hide frames leave the last presentation choice intact.
            keyboardAccessoryEnabled = softwareKeyboardVisible
        }
    }

    var activeWorkspaceWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows).first(where: \.isKeyWindow)
    }

    var keyboardIntersectsWindow: Bool {
        guard let window = activeWorkspaceWindow, !keyboardFrame.isNull,
              keyboardFrame.height > 1 else { return false }
        return window.bounds.intersects(keyboardFrame)
    }

    var softwareKeyboardVisible: Bool {
        keyboardIntersectsWindow && keyboardFrame.height > 120
    }

    func keyboardViewportHeight(in geometry: GeometryProxy) -> CGFloat {
        let content = geometry.frame(in: .global)
        // A floating iPad keyboard doesn't take the entire bottom edge.
        // Rotation can precede the final window geometry. Read the settled
        // docked keyboard boundary instead of retaining the pre-rotation frame.
        let guideFrame = duoHingePresent ? CGRect.null
            : (activeWorkspaceWindow?.keyboardLayoutGuide.layoutFrame ?? .null)
        let frame = guideFrame.height > 120 ? guideFrame : keyboardFrame
        guard !frame.isNull,
              frame.width >= content.width * 0.8,
              frame.maxY >= content.maxY - 1 else { return geometry.size.height }
        return min(geometry.size.height, max(0, frame.minY - content.minY))
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
        let windowBounds = activeWorkspaceWindow?.bounds ?? geometry.frame(in: .global)
        guard windowBounds.height > windowBounds.width,
              duoHingePresent, geometry.size.width >= 600 else { return nil }
        let hingeGlobalY = windowBounds.midY
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
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    toggleFiles()
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
            projectMenu
        }
    }

    /// Only conventional landscape phones use this row. Duo keeps its
    /// established header, pane tabs and system section navigation.
    var phoneLandscapeHeader: some View {
        HStack(spacing: 8) {
            Button(action: toggleFiles) {
                Image(systemName: "sidebar.leading").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Files")
            .accessibilityIdentifier(AccessibilityID.filesToggle)
            VStack(alignment: .leading, spacing: 1) {
                Text(workspace.project?.name ?? "Workspace")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(pane == .code ? workspace.selectedFile : pane.title)
                    .font(.caption.monospaced().weight(.semibold))
            }
            .lineLimit(1).truncationMode(.middle)
            .frame(maxWidth: 160, alignment: .leading)
            .layoutPriority(-1)
            Divider().frame(height: 20)
            WorkspacePaneMenu(selection: $pane, panes: WorkspacePane.workPanes)
            Spacer(minLength: 4)
            ForEach(WorkspaceToolbarActions.primaryPhases, id: \.self) { phase in
                PhaseButton(phase: phase, minimumHitTarget: 44)
            }
            workspaceMenu(includingPrimaryActions: false, minimumHitTarget: 44)
        }
        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.tint)
        .padding(.horizontal, 4).frame(height: 44)
        .background(Color(.secondarySystemBackground))
    }

    var projectMenu: some View {
        workspaceMenu(includingPrimaryActions: false)
    }

    func workspaceMenu(includingPrimaryActions: Bool, minimumHitTarget: CGFloat = 0) -> some View {
            Menu {
                if includingPrimaryActions {
                    ForEach(WorkspaceToolbarActions.primaryPhases, id: \.self) { phase in
                        PhaseButton(phase: phase).labelStyle(.titleAndIcon)
                    }
                    Divider()
                }
                Button {
                    Task { await openOrganizer() }
                } label: {
                    Label("Rename and file…", systemImage: "folder")
                }
                .accessibilityIdentifier(AccessibilityID.projectOrganize)
                if let project = workspace.project {
                    if project.provenance?.source == .github || project.provenance?.source == .files {
                        Button { isShowingImportDetails = true } label: {
                            Label(project.provenance?.importReport?.isPartial == true ? "Partial import — details…" : "Import details…", systemImage: "list.bullet.rectangle")
                        }
                    }
                    ShareLink(
                        item: ProjectExport(project: project),
                        preview: SharePreview(project.name)
                    ) {
                        Label(project.provenance?.importReport?.isPartial == true ? "Export partial snapshot as .tar.gz" : "Export as .tar.gz", systemImage: "square.and.arrow.up")
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
                    .frame(minWidth: minimumHitTarget, minHeight: minimumHitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier(AccessibilityID.projectMenu)
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
