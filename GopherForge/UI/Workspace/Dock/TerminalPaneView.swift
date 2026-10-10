import SwiftUI

/// The project console.
struct TerminalPaneView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Bindable var session: ProjectTerminalSession
    var focusRequest = 0
    var keyboardCommandsOnly = false
    @FocusState private var commandIsFocused: Bool

    static let quickCommands = ["help", "ls", "go build", "go test", "go run", "clear"]

    var body: some View {
        Group {
            if keyboardCommandsOnly {
                content
            } else {
                content.toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Hide keyboard", systemImage: "keyboard.chevron.compact.down") {
                            commandIsFocused = false
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(session.transcript) { entry in
                            TranscriptEntryView(entry: entry).id(entry.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: session.transcript.count) {
                    guard let last = session.transcript.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            Divider()

            if !keyboardCommandsOnly {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Self.quickCommands, id: \.self) { command in
                            Button {
                                session.input = command
                                Task { await session.submit() }
                            } label: {
                                Text(command)
                                    .font(.caption2.monospaced().weight(.semibold))
                                    .foregroundStyle(command == "clear" ? Color.red : GopherForgeTheme.accent)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(
                                        (command == "clear" ? Color.red : GopherForgeTheme.accent).opacity(0.1),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(session.isBusy)
                            .accessibilityIdentifier("terminal.quick.\(command)")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                .background(Color(.secondarySystemBackground))

                Divider()
            }

            HStack(spacing: 8) {
                Text("\(workspace.project?.name ?? "go") $")
                    .font(.caption.monospaced())
                    .foregroundStyle(GopherForgeTheme.accent)
                    .lineLimit(1)
                if keyboardCommandsOnly {
                    TerminalCommandField(text: $session.input, focusRequest: focusRequest) {
                        Task { await session.submit() }
                    }
                    .frame(height: 24)
                } else {
                    TextField("go build", text: $session.input)
                        .font(.caption.monospaced())
                        .focused($commandIsFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.go)
                        .onSubmit { Task { await session.submit() } }
                        .accessibilityIdentifier("terminal.input")
                }
                if session.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await session.submit() }
                    } label: {
                        Image(systemName: "return")
                    }
                    .disabled(session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Run command")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
        }
        .onAppear {
            if focusRequest > 0 { commandIsFocused = true }
        }
        .onChange(of: focusRequest) { _, request in
            if request < 0 { commandIsFocused = false }
            else if request > 0 { commandIsFocused = true }
        }
    }

}

/// A plain text field keeps the Duo keyboard's suggestion shelf out of the
/// space reserved for the terminal's own commands below the work tabs.
private struct TerminalCommandField: UIViewRepresentable {
    @Binding var text: String
    let focusRequest: Int
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "go build"
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.keyboardType = .asciiCapable
        field.returnKeyType = .go
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
        field.accessibilityIdentifier = "terminal.input"
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        if focusRequest < 0 && context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            if field.isFirstResponder { field.resignFirstResponder() }
        } else if focusRequest > 0 && context.coordinator.lastFocusRequest != focusRequest {
            let coordinator = context.coordinator
            DispatchQueue.main.async { [weak field] in
                guard let field, field.window != nil,
                      coordinator.parent.focusRequest == focusRequest else { return }
                if field.becomeFirstResponder() {
                    coordinator.lastFocusRequest = focusRequest
                }
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TerminalCommandField
        var lastFocusRequest = 0

        init(_ parent: TerminalCommandField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

/// One line of the transcript.
///
/// A file printed by `cat` is highlighted with the editor's own tokenizer —
/// showing Go as grey text in a console that sits beside a syntax-highlighted
/// editor teaches the reader that the colours are decoration. Everything else
/// is styled by shape: the command, a diagnostic, a test result.
private struct TranscriptEntryView: View {
    let entry: ProjectTerminalSession.Entry

    var body: some View {
        Group {
            if let language = entry.language {
                GoCodeText(code: entry.text, fileKind: language, fontSize: 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(TerminalLineStyle.attributed(entry.text, kind: entry.kind))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
