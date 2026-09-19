import SwiftUI

/// The project console.
struct TerminalPaneView: View {
    @Bindable var session: ProjectTerminalSession

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

            HStack(spacing: 8) {
                Text("$")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                TextField("go build", text: $session.input)
                    .font(.caption.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { Task { await session.submit() } }
                    .accessibilityIdentifier("terminal.input")
                if session.isBusy {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
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
