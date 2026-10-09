import SwiftUI

/// The project console.
struct TerminalPaneView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Bindable var session: ProjectTerminalSession
    @FocusState private var commandIsFocused: Bool

    private let quickCommands = ["help", "ls", "go build", "go test", "go run", "clear"]

    var body: some View {
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(quickCommands, id: \.self) { command in
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

            HStack(spacing: 8) {
                Text("\(workspace.project?.name ?? "go") $")
                    .font(.caption.monospaced())
                    .foregroundStyle(GopherForgeTheme.accent)
                    .lineLimit(1)
                TextField("go build", text: $session.input)
                    .font(.caption.monospaced())
                    .focused($commandIsFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { Task { await session.submit() } }
                    .accessibilityIdentifier("terminal.input")
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
        .toolbar {
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
