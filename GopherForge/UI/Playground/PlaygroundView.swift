import SwiftUI

struct PlaygroundView: View {
    @Environment(\.scenePhase) private var phase
    @State private var session = PlaygroundSession.shared
    @State private var link = ""
    @State private var filename = ""
    @State private var addingFile = false
    @State private var confirmingReload = false
    @State private var pendingJoin: URL?
    @State private var confirmingJoin = false
    let incomingURL: URL?
    init(incomingURL: URL? = nil) { self.incomingURL = incomingURL }
    private var editorHeight: CGFloat {
        let lines = (session.files[session.selectedFile] ?? "").components(separatedBy: "\n").count
        return CGFloat(min(420, max(220, lines * 20 + 40)))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(session.room == nil ? "Local draft" : (session.connected ? "Connected" : "Disconnected"), systemImage: session.room == nil ? "iphone" : "person.2.wave.2")
                    Spacer()
                    if let room = session.room { Text("\(room.role) · r\(room.revision)").monospaced() }
                }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                DisclosureGroup("Room & AI connection") { roomControls.padding(.top, 10) }
                HStack {
                    Picker("File", selection: $session.selectedFile) {
                        ForEach(session.files.keys.sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Spacer()
                    Button { addingFile = true } label: { Label("File", systemImage: "plus") }.disabled(!session.canEdit)
                }
                SyntaxCodeEditor(
                    text: Binding(get: { session.files[session.selectedFile] ?? "" }, set: { session.update($0) }),
                    fileKind: .of(path: session.selectedFile), fontSize: 14,
                    scrollsVertically: true, isReadOnly: !session.canEdit
                )
                .frame(height: editorHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.secondary.opacity(0.15)))
                .accessibilityIdentifier("playground.source")
                if session.conflict {
                    Text("Shared source changed. Your draft was kept. Save a copy before loading the latest source.").font(.footnote).foregroundStyle(.orange)
                    Button("Load latest shared source") { confirmingReload = true }
                }
                HStack {
                    Button { Task { await session.run(test: false) } } label: { Label("Run here", systemImage: "play.fill") }
                        .accessibilityIdentifier("playground.run")
                    Button { Task { await session.run(test: true) } } label: { Label("Test here", systemImage: "checkmark.diamond") }
                }.buttonStyle(.borderedProminent).disabled(session.isRunning || session.isBusy || !session.canEdit || session.conflict)
                if session.isRunning { ProgressView("Building on this device") }
                Text(session.status).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("playground.status")
                ForEach(session.visibleRequests) { request in
                    Button("AI requests \(request.phase) at r\(request.revision) — run here") {
                        Task { await session.run(test: request.phase == "test", requestID: request.id) }
                    }.disabled(session.isRunning || session.isBusy || session.dirty || session.conflict || !session.canEdit)
                }
                if !session.localOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("This device · Output", systemImage: "terminal").font(.subheadline.bold())
                        Text(session.localOutput).font(.system(.caption, design: .monospaced)).textSelection(.enabled).accessibilityIdentifier("playground.localOutput")
                    }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                }
                if let room = session.room {
                    ForEach(room.runs.reversed()) { run in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(run.device) · \(run.phase) · \(run.status)").font(.subheadline.bold())
                            Text("Revision \(run.revision)\(run.revision == room.revision ? "" : " · older source"). Reported by that device.").font(.caption)
                            Text(run.stdout + "\n" + run.stderr).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                Button("Save an independent project copy") { Task { await saveCopy() } }.accessibilityIdentifier("playground.saveCopy")
                DisclosureGroup("Execution limits & sharing") {
                    Text("Code runs only after your local Run/Test button. Other participants receive Output only. No guaranteed Stop for a tight loop; native sandbox limits still apply. Keep the app foregrounded for live collaboration. Rooms normally last one hour and may end earlier on a relay restart. The relay can read shared source and Output. Save an independent copy before expiry.").font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                    Link("MCP setup for Claude & Codex", destination: URL(string: "https://gopherforge.app/guide/mcp")!).padding(.top, 8)
                }
            }.padding().padding(.bottom, 100).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Playground").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: incomingURL) { if let incomingURL { requestJoin(incomingURL) } }
        .task(id: phase) {
            guard phase == .active else { return }
            while !Task.isCancelled {
                await session.poll()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
        .alert("New Go file", isPresented: $addingFile) {
            TextField("Relative path", text: $filename)
            Button("Add") { session.addFile(filename); filename = "" }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Replace your draft with shared source? Save a project copy first.", isPresented: $confirmingReload) {
            Button("Load latest source", role: .destructive) { session.loadLatest() }
        }
        .confirmationDialog("Your current draft will be saved as an independent project before joining.", isPresented: $confirmingJoin) {
            Button("Save a copy and join") {
                guard let url = pendingJoin else { return }
                Task { if await saveCopy() { await session.join(url, name: UIDevice.current.model, replacingSavedDraft: true) } }
            }
        }
    }
    private var roomControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let room = session.room {
                Text("Expires \(Date(timeIntervalSince1970: room.expiresAt / 1000).formatted())").font(.caption)
                if let url = session.shareURL { ShareLink("Share room", item: url) }
                if let url = session.viewURL { ShareLink("View-only link", item: url) }
                Button("Publish edits") { Task { await session.publish() } }.disabled(!session.dirty || session.isBusy || session.conflict)
                if session.canClose { Button("Close room", role: .destructive) { Task { await session.close() } }.disabled(session.isRunning) }
            } else {
                Text("Creating a room uploads this draft for collaborative editing. No account. No code runs on the relay.").font(.footnote).foregroundStyle(.secondary)
                Button("Create a one-hour room") { Task { await session.create(name: UIDevice.current.model) } }
                    .buttonStyle(.bordered).accessibilityIdentifier("playground.create")
            }
            TextField("Paste Edit/View Playground link", text: $link).textInputAutocapitalization(.never).autocorrectionDisabled()
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("playground.link")
            Button("Join room") { if let url = URL(string: link) { requestJoin(url) } }
                .disabled(link.isEmpty || session.isBusy || session.isRunning)
        }
    }
    @discardableResult private func saveCopy() async -> Bool {
        do {
            _ = try await ProjectLibrary.shared.record(project: session.independentProject(), lastBuild: nil)
            session.status = "Independent copy saved in Project library. It does not follow this room."; return true
        } catch { session.status = error.localizedDescription; return false }
    }
    private func requestJoin(_ url: URL) {
        if session.dirty { pendingJoin = url; confirmingJoin = true }
        else { Task { await session.join(url, name: UIDevice.current.model) } }
    }
}
