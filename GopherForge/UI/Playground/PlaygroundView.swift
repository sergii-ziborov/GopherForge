import SwiftUI

struct PlaygroundView: View {
    @Environment(\.scenePhase) private var phase
    @State private var session = PlaygroundSession.shared
    @State private var link = ""
    @State private var filename = ""
    @State private var addingFile = false
    @State private var editingFilename = false
    @State private var duplicateFile = false
    @State private var confirmingDelete = false
    @State private var confirmingReload = false
    @State private var pendingJoin: URL?
    @State private var confirmingJoin = false
    @State private var encryptedMode = true
    @State private var nicknameInput = ""
    @State private var nicknameError = ""
    @State private var askingNickname = false
    private enum IdentityAction { case create, join(URL), rename }
    @State private var identityAction: IdentityAction = .create
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
                    Label(!session.hasRoom ? "Local draft" : (session.connected ? "Connected" : "Disconnected"), systemImage: !session.hasRoom ? "iphone" : "person.2.wave.2")
                    Spacer()
                    if let secure = session.encrypted { Text("Encrypted · \(secure.role)").monospaced() }
                    else if let room = session.room { Text("\(room.role) · r\(room.revision)").monospaced() }
                }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                DisclosureGroup("Room & AI connection") { roomControls.padding(.top, 10) }
                HStack {
                    Picker("File", selection: $session.selectedFile) {
                        ForEach(session.files.keys.sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Spacer()
                    Menu {
                        Button("Rename / move") { filename = session.selectedFile; duplicateFile = false; editingFilename = true }.disabled(session.selectedFile == "main.go")
                        Button("Duplicate") { filename = "copy-" + session.selectedFile; duplicateFile = true; editingFilename = true }
                        Button("Delete file", role: .destructive) { confirmingDelete = true }.disabled(session.selectedFile == "main.go")
                    } label: { Image(systemName: "ellipsis.circle") }.disabled(!session.canEdit || session.isRunning || session.isBusy)
                    Button { addingFile = true } label: { Label("File", systemImage: "plus") }.disabled(!session.canEdit)
                }
                SyntaxCodeEditor(
                    text: Binding(get: { session.files[session.selectedFile] ?? "" }, set: { session.update($0) }),
                    fileKind: .of(path: session.selectedFile), fontSize: 14,
                    revealLine: session.revealLine, onReveal: { session.revealLine = nil },
                    scrollsVertically: true,
                    breakpointLines: session.debugger.breakpoints[session.selectedFile] ?? [],
                    executionLine: session.debugger.pause?.point.file == session.selectedFile ? session.debugger.pause?.point.line : nil,
                    onToggleBreakpoint: { session.debugger.toggle(file: session.selectedFile, line: $0) },
                    isReadOnly: !session.canEdit || session.isRunning,
                    peerCursors: session.remoteCursors.filter { $0.path == session.selectedFile },
                    onSelectionChange: { range in session.setCursor(anchor: range.location, head: NSMaxRange(range)) }
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
                }.buttonStyle(.borderedProminent).disabled(session.isRunning || session.isBusy || session.conflict)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        Button("Debug", systemImage: "ladybug") { Task { await session.run(test: false, debug: true) } }
                        Button("Check", systemImage: "checkmark.circle") { Task { await session.checkOrFormat(format: false) } }
                        Button("Format", systemImage: "text.alignleft") { Task { await session.checkOrFormat(format: true) } }
                        Button("Prepare packages", systemImage: "shippingbox") { Task { await session.preparePackages() } }
                    }.buttonStyle(.bordered).disabled(session.isRunning || session.isBusy || !session.canEdit)
                }
                if session.debugger.isActive { playgroundDebugger }
                if session.isRunning && !session.debugger.isActive { ProgressView("Building on this device") }
                if !session.preparedModules.isEmpty { Text("Local packages: " + session.preparedModules.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
                if let secure = session.encrypted {
                    ForEach(secure.state.peers) { peer in Text("● \(peer.name)").font(.caption).foregroundStyle(.secondary) }
                    if !secure.state.changes.isEmpty { DisclosureGroup("Recent changes") {
                        ForEach(secure.state.changes.suffix(8).reversed()) { change in Text("\(change.name) · \(change.kind): \(change.paths.joined(separator: ", "))").font(.caption) }
                    } }
                    ForEach(secure.state.runs.reversed()) { run in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(run.name) · \(run.phase) · \(run.succeeded ? "Succeeded" : "Failed")").font(.subheadline.bold())
                            Text((try? PlaygroundCRDT.sourceHash(session.files)) == run.sourceHash ? "Current source · device-reported result" : "Older source · device-reported result").font(.caption)
                            Text(run.stdout + "\n" + run.stderr).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    if !secure.state.deleted.isEmpty {
                        DisclosureGroup("Recover deleted files") {
                            ForEach(secure.state.deleted) { file in Button("Restore " + file.path) { session.restoreSharedFile(file.id) }.disabled(!session.canEdit) }
                        }
                    }
                }

                Text(session.status).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("playground.status")
                ForEach(session.visibleRequests) { request in
                    Button("AI requests \(request.phase) at r\(request.revision) — run here") {
                        Task { await session.run(test: request.phase == "test", requestID: request.id) }
                    }.disabled(session.isRunning || session.isBusy || session.dirty || session.conflict || !session.canEdit)
                }
                if !session.localOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Last local Output", systemImage: "terminal").font(.subheadline.bold())
                        Text(session.localOutput).font(.system(.caption, design: .monospaced)).textSelection(.enabled).accessibilityIdentifier("playground.localOutput")
                    }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                }
                if let room = session.room {
                    ForEach(room.participants) { participant in Text("● \(participant.name) · \(participant.kind)").font(.caption).foregroundStyle(.secondary) }
                    ForEach((room.changes ?? []).suffix(5).reversed()) { change in Text("\(change.name) changed \(change.paths.joined(separator: ", ")) · r\(change.revision)").font(.caption).foregroundStyle(.secondary) }
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
                    Text("Run, Test and Debug require your local button. Receiving an edit, cursor or MCP request never executes it. Debug Stop acts at a project checkpoint; an ordinary tight loop has no guaranteed Stop. Encrypted rooms merge text and encrypt source, Output and cursors before the relay. Compatible rooms support released native apps and remote MCP; their relay can read source and Output. Your nickname is a display label, not verified identity. Keep the app foregrounded and save an independent copy before expiry or a relay restart.").font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
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
        .sheet(isPresented: $askingNickname) { nicknamePrompt }
        .onDisappear { session.debugger.stop() }
        .alert("New Go file", isPresented: $addingFile) {
            TextField("Relative path", text: $filename)
            Button("Add") { session.addFile(filename); filename = "" }
            Button("Cancel", role: .cancel) {}
        }
        .alert(duplicateFile ? "Duplicate file" : "Rename / move file", isPresented: $editingFilename) {
            TextField("Relative path", text: $filename)
            Button("Save") { session.changeFile(session.selectedFile, target: filename, duplicate: duplicateFile) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this shared file? Save an independent copy first. Encrypted rooms keep recoverable deleted files.", isPresented: $confirmingDelete) {
            Button("Delete file", role: .destructive) { session.changeFile(session.selectedFile, remove: true) }
        }
        .confirmationDialog("Replace your draft with shared source? Save a project copy first.", isPresented: $confirmingReload) {
            Button("Load latest source", role: .destructive) { session.loadLatest() }
        }
        .confirmationDialog("Your current draft will be saved as an independent project before joining.", isPresented: $confirmingJoin) {
            Button("Save a copy and join") {
                guard let url = pendingJoin else { return }
                Task { if await saveCopy() { showNickname(for: .join(url)) } }
            }
        }
    }
    private var roomControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.hasRoom {
                Text("You are \(session.nickname)").font(.subheadline.bold())
                Button("Change nickname") { showNickname(for: .rename) }
                if let expiresAt = session.encrypted?.expiresAt ?? session.room?.expiresAt { Text("Expires \(Date(timeIntervalSince1970: expiresAt / 1000).formatted())").font(.caption) }
                if let url = session.shareURL { ShareLink("Share Edit link", item: url) }
                if let url = session.viewURL { ShareLink("Share View-only link", item: url) }
                Button(session.encrypted == nil ? "Publish edits" : "Sync encrypted edits") { Task { await session.publish() } }
                    .disabled(session.isBusy || session.conflict || !session.canEdit)
                if session.canClose { Button("Close room", role: .destructive) { Task { await session.close() } }.disabled(session.isRunning) }
                Button("Leave room, keep local draft") { session.leave() }.disabled(session.isRunning || session.isBusy)
            } else {
                Picker("Room type", selection: $encryptedMode) {
                    Text("Encrypted · live editing").tag(true)
                    Text("Compatible · MCP / older apps").tag(false)
                }
                Text(encryptedMode ? "Source, Output and cursors are encrypted before sharing. Live text merging works with the browser and this native build." : "Share with remote MCP clients or released native apps. The relay sees source and Output; conflicting revisions keep your draft.").font(.footnote).foregroundStyle(.secondary)
                Button("Create a one-hour room") { showNickname(for: .create) }
                    .buttonStyle(.bordered).accessibilityIdentifier("playground.create")
                    .disabled(session.isBusy || session.isRunning)
            }
            TextField("Paste Edit/View Playground link", text: $link).textInputAutocapitalization(.never).autocorrectionDisabled()
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("playground.link")
            Button("Join room") { if let url = URL(string: link) { requestJoin(url) } }
                .disabled(link.isEmpty || session.isBusy || session.isRunning)
            Link("MCP setup and sharing guide", destination: URL(string: "https://gopherforge.app/guide/mcp")!)
        }
    }
    private var nicknamePrompt: some View {
        NavigationStack {
            Form {
                Section("How should we call you?") {
                    TextField("Nickname", text: $nicknameInput).textContentType(.nickname).textInputAutocapitalization(.words).autocorrectionDisabled()
                        .accessibilityIdentifier("playground.nickname")
                    Text("Your nickname appears beside your cursor, edits and results. It is a display label, not a verified identity.").font(.footnote).foregroundStyle(.secondary)
                    if !nicknameError.isEmpty { Text(nicknameError).foregroundStyle(.red) }
                }
                Button("Continue") {
                    do {
                        let name = try PlaygroundIdentity.nickname(nicknameInput)
                        askingNickname = false
                        switch identityAction {
                        case .create: Task { await session.create(name: name, encrypted: encryptedMode) }
                        case .join(let url): Task { await session.join(url, name: name, replacingSavedDraft: true) }
                        case .rename: Task { await session.renameParticipant(name) }
                        }
                    } catch { nicknameError = error.localizedDescription }
                }.accessibilityIdentifier("playground.nickname.continue")
            }.navigationTitle("Participant nickname").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { askingNickname = false } } }
        }.presentationDetents([.medium, .large])
    }
    private func showNickname(for action: IdentityAction) {
        identityAction = action; nicknameInput = session.nickname; nicknameError = ""; askingNickname = true
    }
    private var playgroundDebugger: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(session.debugger.message).font(.caption.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Stop", systemImage: "stop.fill", role: .destructive) { session.debugger.stop() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("playground.debug.stop")
            }
            ScrollView(.horizontal) {
                HStack {
                    if session.debugger.pause != nil {
                        Button("Continue") { session.debugger.resume() }
                        Button("Step into") { session.debugger.resume(step: .into) }
                        Button("Step over") { session.debugger.resume(step: .over) }
                        Button("Step out") { session.debugger.resume(step: .out) }
                    }
                }.buttonStyle(.bordered)
            }
            if let pause = session.debugger.pause {
                Text("\(pause.point.file):\(pause.point.line) · goroutine \(pause.goroutine)").font(.caption.monospaced())
                ForEach(Array(pause.frames.enumerated()), id: \.offset) { _, frame in
                    Button("\(frame.function) · \(frame.file):\(frame.line)") { session.selectedFile = frame.file; session.revealLine = frame.line }
                }
                ForEach(pause.locals.keys.sorted(), id: \.self) { name in Text("\(name) = \(pause.locals[name] ?? "")").font(.caption.monospaced()).textSelection(.enabled) }
            }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
    @discardableResult private func saveCopy() async -> Bool {
        do {
            _ = try await ProjectLibrary.shared.record(project: session.independentProject(), lastBuild: nil)
            session.status = "Independent copy saved in Project library. It does not follow this room."; return true
        } catch { session.status = error.localizedDescription; return false }
    }
    private func requestJoin(_ url: URL) {
        if session.dirty { pendingJoin = url; confirmingJoin = true }
        else { showNickname(for: .join(url)) }
    }
}
