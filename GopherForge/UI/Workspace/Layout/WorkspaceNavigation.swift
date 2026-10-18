import SwiftUI

extension WorkspaceView {
    var duoWorkspaceHeader: some View {
        let topInset = activeWorkspaceWindow?.safeAreaInsets.top ?? 0
        // Each row owns its height. A second window-inset read inside a
        // GeometryReader can change after the enclosing frame was measured.
        return VStack(spacing: 0) {
            if topInset > 0 {
                GeometryReader { geometry in
                    Text(workspace.project?.name ?? "Workspace")
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.leading, max(16, duoHeaderInsets(in: geometry, y: 0, height: topInset).leading))
                        .padding(.trailing, duoHeaderInsets(in: geometry, y: 0, height: topInset).trailing)
                        .frame(maxWidth: .infinity, minHeight: topInset, maxHeight: topInset, alignment: .leading)
                }
                .frame(height: topInset)
            }
            GeometryReader { geometry in
                HStack(spacing: 6) {
                    Button(action: toggleFiles) {
                        Image(systemName: "sidebar.leading")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Toggle Files")
                    .accessibilityValue(usesLaptopLayout || !layout.hasNavigator
                        ? (isDrawerOpen ? "Open" : "Closed")
                        : (navigatorCollapsed ? "Closed" : "Open"))
                    .accessibilityIdentifier(AccessibilityID.filesToggle)
                    Button {
                        dismissLaptopKeyboard()
                        navigation.show(.projects)
                    } label: {
                        Label("Projects", systemImage: "chevron.left")
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to Projects")
                    .labelStyle(.titleAndIcon)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier(usesLaptopLayout ? AccessibilityID.laptopProjectsBack : "workspace.projectsBack")
                    if topInset == 0 { Text(workspace.project?.name ?? "Workspace")
                        .font(.headline).lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(.primary)
                        .layoutPriority(-1)
                    }
                    Spacer(minLength: 4)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            ForEach(WorkspaceToolbarActions.primaryPhases, id: \.self) { phase in
                                PhaseButton(phase: phase, minimumHitTarget: 44)
                            }
                            workspaceMenu(includingPrimaryActions: false, minimumHitTarget: 44)
                        }
                        HStack(spacing: 4) {
                            PhaseButton(phase: .run, minimumHitTarget: 44)
                            workspaceMenu(includingPrimaryActions: true, minimumHitTarget: 44)
                        }
                    }
                    .font(.title3)
                    .padding(.horizontal, 4)
                    .background(.thinMaterial, in: Capsule())
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .padding(.leading, duoHeaderInsets(in: geometry, y: 0, height: 44).leading)
                .padding(.trailing, duoHeaderInsets(in: geometry, y: 0, height: 44).trailing)
                .frame(width: geometry.size.width, height: 44)
            }
            .frame(height: 44)
        }
        .background(Color(.secondarySystemBackground))
        // A container identifier propagates to every child in SwiftUI and
        // would overwrite Files, Projects and the phase button identifiers.
    }

    func duoHeaderInsets(in geometry: GeometryProxy, y: CGFloat = 0, height: CGFloat? = nil) -> EdgeInsets {
        let band = CGRect(x: 0, y: y, width: geometry.size.width, height: height ?? geometry.size.height)
        var leading: CGFloat = max(8, geometry.safeAreaInsets.leading)
        var trailing: CGFloat = max(8, geometry.safeAreaInsets.trailing)
        var obstacles: [CGRect] = []
        if #available(iOS 27.1, *) {
            obstacles = geometry.reservedRegions(kind: .occlusion).map { region in
                region.frame.insetBy(dx: -max(region.margins.leading, region.margins.trailing), dy: 0)
            }
        }
        if let window = activeWorkspaceWindow,
           let status = window.windowScene?.statusBarManager?.statusBarFrame,
           !status.isEmpty, status.width < window.bounds.width * 0.8 {
            let global = geometry.frame(in: .global)
            obstacles.append(status.offsetBy(dx: -global.minX, dy: -global.minY))
        }
        for rect in obstacles where rect.intersects(band) {
            if rect.midX > band.midX {
                trailing = max(trailing, band.maxX - rect.minX + 8)
            } else {
                leading = max(leading, rect.maxX + 8)
            }
        }
        return EdgeInsets(top: 0, leading: leading, bottom: 0, trailing: trailing)
    }

    func toggleFiles() {
        withAnimation(.easeOut(duration: 0.2)) {
            if usesLaptopLayout {
                isDrawerOpen.toggle()
                laptopShouldFocus = false
                dismissLaptopKeyboard()
            } else if layout.hasNavigator {
                navigatorCollapsed.toggle()
            } else {
                isDrawerOpen.toggle()
            }
        }
    }

    func navigatorWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(170, CGFloat(navigatorWidth)), max(170, min(360, availableWidth - 280)))
    }

    func navigatorResizeHandle(availableWidth: CGFloat) -> some View {
        ZStack {
            Color(.secondarySystemBackground)
            Capsule().fill(Color(.tertiaryLabel)).frame(width: 3, height: 38)
        }
        .frame(width: 12)
        .contentShape(Rectangle())
        .highPriorityGesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                if navigatorDragStart == nil { navigatorDragStart = navigatorWidth }
                let proposed = (navigatorDragStart ?? navigatorWidth) + Double(value.translation.width)
                navigatorWidth = min(max(170, proposed), max(170, min(360, Double(availableWidth) - 280)))
            }
            .onEnded { value in
                if (navigatorDragStart ?? navigatorWidth) + Double(value.translation.width) < 120 {
                    withAnimation {
                        if usesLaptopLayout { isDrawerOpen = false }
                        else { navigatorCollapsed = true }
                    }
                }
                navigatorDragStart = nil
            })
        .accessibilityIdentifier("workspace.navigatorResize")
        .accessibilityLabel("Resize Files")
        .accessibilityValue("\(Int(navigatorWidth)) points")
        .accessibilityAdjustableAction { direction in
            navigatorWidth += direction == .increment ? 30 : -30
            navigatorWidth = Double(navigatorWidth(for: availableWidth))
        }
    }
}
