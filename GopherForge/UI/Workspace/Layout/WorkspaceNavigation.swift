import SwiftUI

extension WorkspaceView {
    var duoWorkspaceHeader: some View {
        HStack(spacing: 8) {
            Button {
                dismissLaptopKeyboard()
                navigation.show(.projects)
            } label: {
                Label("Projects", systemImage: "chevron.left")
            }
            .accessibilityLabel("Back to Projects")
            .labelStyle(.titleAndIcon)
            .accessibilityIdentifier(usesLaptopLayout ? AccessibilityID.laptopProjectsBack : "workspace.projectsBack")
            Button(action: toggleFiles) {
                Image(systemName: "sidebar.leading")
            }
            .accessibilityLabel("Toggle Files")
            .accessibilityIdentifier(AccessibilityID.filesToggle)
            Text(workspace.project?.name ?? "Workspace")
                .font(.headline).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            ForEach(WorkspaceToolbarActions.primaryPhases, id: \.self) { phase in
                PhaseButton(phase: phase)
            }
            projectMenu
        }
        .labelStyle(.iconOnly)
        .font(.subheadline)
        .frame(height: 44)
        .padding(.horizontal, 12)
        .padding(.trailing, 82)
        .background(Color(.secondarySystemBackground))
        .accessibilityIdentifier("workspace.duoHeader")
    }

    func toggleFiles() {
        withAnimation(.easeOut(duration: 0.2)) {
            if usesLaptopLayout {
                laptopShowsFiles.toggle()
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
                    withAnimation { navigatorCollapsed = true }
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
