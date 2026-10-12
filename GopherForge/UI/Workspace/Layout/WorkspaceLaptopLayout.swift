import SwiftUI

extension WorkspaceView {
    /// Book keeps the adjustable Files pane and the active work pane. A default
    /// ArrangementView added a second strip of padding around the crease.
    @available(iOS 27.1, *)
    func foldedLayout(
        terminal: ProjectTerminalSession,
        layout: WorkspaceLayout,
        division: CGRect,
        width: CGFloat
    ) -> some View {
        columnsLayout(terminal: terminal, width: width)
    }

    /// The upper display is the active work surface. With Code or Terminal
    /// selected, the system keyboard owns the lower display and the helper row
    /// sits immediately below these tabs. Results replace the keyboard below
    /// the hinge while the last work surface remains visible above it.
    func laptopLayout(terminal: ProjectTerminalSession, division: CGRect?) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                WorkspacePaneContent(
                    pane: laptopWorkPane,
                    terminal: terminal,
                    fontSize: fontSize,
                    focusRequest: laptopShouldFocus ? laptopFocusGeneration : -1,
                    keyboardCommandsOnly: true,
                    onEditorReady: { textView in
                        if laptopWorkPane == .code && laptopEditor !== textView {
                            laptopEditor = textView
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: laptopWorkHeight(in: geometry, division: division))

                Divider()
                laptopTabs
                Divider()

                if keyboardVisible && !laptopShowsFiles {
                    if laptopPane == .code, let laptopEditor {
                        GoKeyboardHelperBar(textView: laptopEditor, fileKind: workspace.fileKind)
                            .frame(height: 46)
                    } else if laptopPane == .terminal {
                        laptopTerminalHelpers(terminal)
                    }
                }

                if laptopShowsFiles {
                    ProjectNavigatorView(onOpenFile: {
                        selectLaptopPane(.code)
                        revealCode()
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if laptopPane != .code && laptopPane != .terminal {
                    WorkspacePaneContent(
                        pane: laptopPane,
                        terminal: terminal,
                        fontSize: fontSize,
                        onRevealCode: { selectLaptopPane(.code) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !keyboardVisible {
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            if laptopPane == .code || laptopPane == .terminal {
                scheduleInitialLaptopFocus()
            }
        }
    }

    var laptopTabs: some View {
        HStack(spacing: 0) {
            Button {
                laptopShowsFiles = true
                laptopShouldFocus = false
                dismissLaptopKeyboard()
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
                    set: { selectLaptopPane($0) }
                ),
                panes: WorkspacePane.workPanes
            )
        }
        .background(Color(.secondarySystemBackground))
    }

    func laptopTerminalHelpers(_ terminal: ProjectTerminalSession) -> some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TerminalPaneView.quickCommands, id: \.self) { command in
                        Button(command) {
                            terminal.input = command
                            Task { await terminal.submit() }
                        }
                        .font(.caption.monospaced())
                        .disabled(terminal.isBusy)
                        .accessibilityIdentifier("terminal.quick.\(command)")
                    }
                }
                .padding(.horizontal, 12)
            }
            Button("Hide keyboard", systemImage: "keyboard.chevron.compact.down") {
                laptopShouldFocus = false
                dismissLaptopKeyboard()
            }
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .accessibilityIdentifier("terminal.hideKeyboard")
        }
        .frame(height: 46)
        .background(Color(.secondarySystemBackground))
    }

    func selectLaptopPane(_ destination: WorkspacePane) {
        laptopPane = destination
        pane = destination
        laptopShowsFiles = false
        if destination == .code || destination == .terminal {
            laptopWorkPane = destination
            if destination == .terminal { laptopEditor = nil }
            requestLaptopFocus()
        } else {
            laptopShouldFocus = false
            dismissLaptopKeyboard()
        }
    }

    func dismissLaptopKeyboard() {
        // A picker inside a menu can keep the text view as first responder
        // through the same SwiftUI update that swaps the lower pane. Dismiss
        // it after the menu closes as well as updating the editor's request.
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }

    func requestLaptopFocus() {
        laptopFocusGeneration += 1
        laptopShouldFocus = true
    }

    func laptopWorkHeight(in geometry: GeometryProxy, division: CGRect?) -> CGFloat {
        let hingeHeight = min(division?.maxY ?? geometry.size.height * 0.5, geometry.size.height)
        // The Duo keyboard's rounded upper edge covers 21 points of the
        // helper row at the division. Leave five more points for separation.
        return max(0, hingeHeight - (keyboardVisible ? 26 : 0))
    }

    func scheduleInitialLaptopFocus() {
        // The editor can appear before project selection has settled. Focusing
        // it during that replacement leaves a first responder with no keyboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard usesLaptopLayout,
                  laptopPane == .code || laptopPane == .terminal,
                  !laptopShouldFocus else { return }
            requestLaptopFocus()
        }
    }

}
