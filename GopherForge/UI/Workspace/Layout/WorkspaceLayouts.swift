import SwiftUI

extension WorkspaceView {
    func workspaceArea(terminal: ProjectTerminalSession) -> some View {
        GeometryReader { geometry in
            let availableLayout = WorkspaceLayout.resolve(
                width: geometry.size.width,
                isPad: UIDevice.current.userInterfaceIdiom == .pad
            )
            let division = activeDivisionFrame(in: geometry)
            let horizontalDivision = division.flatMap { $0.width > $0.height * 2 ? $0 : nil }
            let laptopDivision = horizontalDivision
                ?? (division == nil ? fallbackLaptopDivision(in: geometry) : nil)
            let showsLaptop = forceLaptopLayout || laptopDivision != nil
            workspaceContent(
                terminal: terminal,
                layout: availableLayout,
                width: geometry.size.width,
                division: division,
                laptopDivision: laptopDivision,
                showsLaptop: showsLaptop
            )
            .frame(width: geometry.size.width,
                   height: showsLaptop ? geometry.size.height : keyboardViewportHeight(in: geometry),
                   alignment: .topLeading)
            .clipped()
            .onAppear {
                adoptLayout(availableLayout)
                usesLaptopLayout = showsLaptop
            }
            .onChange(of: availableLayout) { _, newValue in adoptLayout(newValue) }
            .onChange(of: showsLaptop) { wasLaptop, isLaptop in
                usesLaptopLayout = isLaptop
                if isLaptop && !wasLaptop {
                    laptopPane = pane
                    if pane == .code || pane == .terminal {
                        laptopWorkPane = pane
                        requestLaptopFocus()
                    }
                }
            }
        }
    }

    @ViewBuilder
    func workspaceContent(
        terminal: ProjectTerminalSession,
        layout: WorkspaceLayout,
        width: CGFloat,
        division: CGRect?,
        laptopDivision: CGRect?,
        showsLaptop: Bool
    ) -> some View {
        if showsLaptop {
            laptopLayout(terminal: terminal, division: forceLaptopLayout ? nil : laptopDivision)
        } else if #available(iOS 27.1, *), layout != .compact, division != nil {
            foldedLayout(terminal: terminal, layout: layout, division: division!, width: width)
        } else if duoHingePresent && layout != .compact {
            columnsLayout(terminal: terminal, width: width)
        } else {
            switch layout {
            case .compact: compactLayout(terminal: terminal)
            case .columns: columnsLayout(terminal: terminal, width: width)
            case .canvas: canvasLayout(terminal: terminal, width: width)
            case .tablet: tabletLayout(terminal: terminal, width: width)
            }
        }
    }

    func adoptLayout(_ newLayout: WorkspaceLayout) {
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
    func columnsLayout(terminal: ProjectTerminalSession, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            if !navigatorCollapsed {
                ProjectNavigatorView(onOpenFile: revealCode)
                    .frame(width: navigatorWidth(for: width))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                navigatorResizeHandle(availableWidth: width)
            }
            paneStack(terminal: terminal)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
    }

    /// On the broad inner display, code and the selected result or terminal
    /// remain visible at the same time. Both side panels shrink with the
    /// window, leaving a useful minimum width for the editor.
    func canvasLayout(terminal: ProjectTerminalSession, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            if !navigatorCollapsed {
                ProjectNavigatorView(onOpenFile: revealCode)
                    .frame(width: navigatorWidth(for: width))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                navigatorResizeHandle(availableWidth: width)
            }
            WorkspacePaneContent(pane: .code, terminal: terminal, fontSize: fontSize)
                .frame(minWidth: 0, maxWidth: .infinity)
            Divider()
            dockContent(terminal: terminal)
                .frame(width: WorkspaceLayout.inspectorWidth(for: width))
        }
    }

    func tabletLayout(terminal: ProjectTerminalSession, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !navigatorCollapsed {
                    ProjectNavigatorView(onOpenFile: revealCode)
                        .frame(width: navigatorWidth(for: width))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    navigatorResizeHandle(availableWidth: width)
                }
                WorkspacePaneContent(pane: .code, terminal: terminal, fontSize: fontSize)
            }

            dockResizeHandle
            dockContent(terminal: terminal)
            .frame(height: dockHeight)
        }
    }

    func dockContent(terminal: ProjectTerminalSession) -> some View {
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
    var dockSelection: Binding<WorkspacePane> {
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
    func compactLayout(terminal: ProjectTerminalSession) -> some View {
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
    var filesOpenSwipe: some Gesture {
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
    func revealCode() {
        withAnimation(.easeOut(duration: 0.2)) {
            pane = WorkspacePane.afterSelectingFile()
        }
    }

    /// The seam between editor and dock. Dragging it up gives the dock room,
    /// dragging it down gives it back to the code; the grabber says it moves.
    var dockResizeHandle: some View {
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

    func paneStack(terminal: ProjectTerminalSession) -> some View {
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

}
