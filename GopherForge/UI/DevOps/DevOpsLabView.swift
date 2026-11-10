import SwiftUI

struct DevOpsLabView: View {
    @State private var session: DevOpsLabSession
    @State private var resetting = false
    @FocusState private var scriptFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    init(lab: DevOpsLab) { _session = State(initialValue: DevOpsLabSession(lab: lab)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(session.lab.objective).font(.headline)
                Text(session.lab.instructions).textSelection(.enabled)
                Text("Local shell subset · private /lab · no network or host processes. Docker, Kubernetes and SSH commands are unavailable.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Script").font(.headline)
                TextEditor(text: $session.source).font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .focused($scriptFocused)
                    .frame(minHeight: 150).overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                    .disabled(session.isRunning).accessibilityIdentifier("devops.source")
                if let message = session.status { Text(message).foregroundStyle(.red) }
                Text(session.transcript).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("devops.output")
                if !session.checks.isEmpty {
                Text("Result checks").font(.headline)
                ForEach(Array(session.checks.enumerated()), id: \.offset) { _, check in
                    Label(check.description, systemImage: check.passed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(check.passed ? .green : .secondary)
                }
                Text("\(session.checks.filter(\.passed).count) of \(session.checks.count) checks passed").bold().accessibilityIdentifier("devops.checks")
                }
                DisclosureGroup("Lab files · \(session.state.files.count)") {
                    ForEach(session.state.files.keys.sorted(), id: \.self) { path in
                        DisclosureGroup(path) { Text(session.state.files[path] ?? "").font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    }
                }
            }.padding().frame(maxWidth: 850).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { controls }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { scriptFocused = false } } }
        .navigationTitle(session.lab.title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("Reset this lab?", isPresented: $resetting) {
            Button("Reset lab files", role: .destructive) { session.reset() }
        } message: { Text("Only files in this lab return to their starting state. Your projects, other labs and course progress are kept.") }
        .onDisappear { session.stop(); session.saveDraft() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.stop(); session.saveDraft() } }
    }

    private var controls: some View {
        HStack {
            if session.isRunning { ProgressView(); Button("Stop", role: .destructive) { session.stop() }.accessibilityIdentifier("devops.stop") }
            else { Button("Run script", systemImage: "play.fill") { scriptFocused = false; Task { await session.run() } }.buttonStyle(.borderedProminent).disabled(session.needsReset).accessibilityIdentifier("devops.run") }
            Spacer()
            Button("Reset lab", role: .destructive) { resetting = true }.disabled(session.isRunning)
        }.padding(12).background(.bar)
    }
}
