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
                            Text(entry.text)
                                .font(.caption.monospaced())
                                .foregroundStyle(color(for: entry.kind))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
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

    private func color(for kind: ProjectTerminalSession.Entry.Kind) -> Color {
        switch kind {
        case .command: GopherForgeTheme.ember
        case .output: .primary
        case .failure: .red
        }
    }
}
