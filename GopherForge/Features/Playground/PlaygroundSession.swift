import Foundation

struct PlaygroundRoom: Codable, Sendable {
    struct Participant: Codable, Identifiable, Sendable { let id: String; let name: String; let kind: String }
    struct Run: Codable, Identifiable, Sendable {
        let id: String; let device: String; let revision: Int; let phase: String
        let status: String; let stdout: String; let stderr: String
    }
    struct Request: Codable, Identifiable, Sendable {
        let id: String; let revision: Int; let phase: String; let targetID: String?
    }
    struct Capabilities: Codable, Sendable { let owner: String; let edit: String; let view: String }
    let id: String; let title: String; let revision: Int; let expiresAt: Double
    let files: [String: String]; let role: String; let participantID: String?
    let participants: [Participant]; let runs: [Run]; let requests: [Request]
    let capabilities: Capabilities?; let participantCapability: String?
}

enum PlaygroundLink {
    static func capability(_ url: URL) -> String? {
        let valid = (url.scheme == "https" && url.host == "gopherforge.app" && url.path == "/playground")
            || (url.scheme == "gopherforge" && url.host == "playground")
        guard valid, let fragment = url.fragment,
              let token = URLComponents(string: "?" + fragment)?.queryItems?.first(where: { $0.name == "cap" })?.value,
              token.range(of: #"^[a-f0-9]{24}\.[A-Za-z0-9_-]{32}$"#, options: .regularExpression) != nil else { return nil }
        return token
    }
    static func web(_ token: String) -> URL { URL(string: "https://gopherforge.app/playground#cap=\(token)")! }
}

/// Collaboration transports text and results only. No polling path calls a compiler.
@MainActor
final class PlaygroundTransport {
    let endpoint: URL
    let session: URLSession
    init(endpoint: URL = URL(string: "https://gopherforge.app/api/playground")!, session: URLSession = .shared) {
        self.endpoint = endpoint; self.session = session
    }
    func call<T: Decodable>(_ input: [String: Any], token: String? = nil, as: T.Type = T.self) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"; request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: input)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            let value = try? JSONDecoder().decode(ServiceFailure.self, from: data)
            throw ServiceFailure(error: value?.error ?? "Connection failed. Your local source is kept.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    struct ServiceFailure: Codable, LocalizedError { let error: String; var errorDescription: String? { error } }
}

@MainActor @Observable
final class PlaygroundSession {
    // Every scene/deep link on this device uses one draft and one compiler owner.
    // Returning during an in-flight run cannot create a second writer to its file.
    static let shared = PlaygroundSession()
    struct PendingResult: Codable {
        let runID: String; let stdout: String; let stderr: String; let succeeded: Bool
    }
    private struct Saved: Codable {
        let files: [String: String]; let seat: String?; let owner: String?; let edit: String?; let view: String?
        let room: PlaygroundRoom?; let dirty: Bool; let pending: PendingResult?
    }
    static let starter = ["go.mod": "module playground\n\ngo 1.27.1\n", "main.go": "package main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"Hello from my device\")\n}\n"]
    var files = starter
    var selectedFile = "main.go"
    private(set) var room: PlaygroundRoom?
    private(set) var dirty = false
    private(set) var conflict = false
    private(set) var isRunning = false
    private(set) var isBusy = false
    private(set) var connected = false
    var status = "Local draft. Create a room only when you want to share this source."
    private(set) var localOutput = ""
    private var seat: String?
    private var owner: String?
    private var edit: String?
    private var view: String?
    private var pending: PendingResult?
    private let transport: PlaygroundTransport
    private let compiler: WasmGoCompiler
    private let execute: (@Sendable (GoSourceSnapshot, Bool) async -> CompilationResult)?
    private let storageURL: URL
    var canEdit: Bool { room?.role != "view" }
    var canClose: Bool { owner != nil }
    var shareURL: URL? { (edit ?? view).map(PlaygroundLink.web) }
    var viewURL: URL? { view.map(PlaygroundLink.web) }
    var visibleRequests: [PlaygroundRoom.Request] {
        room?.requests.filter { $0.revision == room?.revision && ($0.targetID == nil || $0.targetID == room?.participantID) } ?? []
    }

    init(transport: PlaygroundTransport = PlaygroundTransport(), compiler: WasmGoCompiler = WasmGoCompiler(), storageURL: URL? = nil,
         execute: (@Sendable (GoSourceSnapshot, Bool) async -> CompilationResult)? = nil) {
        self.transport = transport; self.compiler = compiler
        self.execute = execute
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "GopherForge/playground-draft-v1.json")
        if let data = try? Data(contentsOf: self.storageURL), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            files = saved.files; seat = saved.seat; owner = saved.owner; edit = saved.edit; view = saved.view
            room = saved.room; dirty = saved.dirty; pending = saved.pending
            status = "Local draft restored. Reconnecting never starts a run."
        }
    }
    func update(_ text: String) {
        guard canEdit else { return }
        files[selectedFile] = text; dirty = true; save()
    }
    func addFile(_ name: String) {
        guard canEdit, name.range(of: #"^[a-zA-Z0-9_/-]+\.go$"#, options: .regularExpression) != nil,
              !name.hasPrefix("/"), !name.contains(".."), files[name] == nil, files.count < 32 else { status = "Use a new relative .go path (up to 32 files)."; return }
        files[name] = "package main\n"; selectedFile = name; dirty = true; save()
    }
    private func save() {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let value = Saved(files: files, seat: seat, owner: owner, edit: edit, view: view, room: room, dirty: dirty, pending: pending)
            try JSONEncoder().encode(value).write(to: storageURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { status = "Draft could not be saved: \(error.localizedDescription). Save a separate project copy before leaving." }
    }
    func create(name: String) async {
        guard !isBusy, !isRunning else { return }; isBusy = true; defer { isBusy = false }
        do {
            let created: PlaygroundRoom = try await transport.call(["op": "create", "files": files, "title": "Go study room", "ttlSeconds": 3600])
            guard let caps = created.capabilities else { return }
            let joined: PlaygroundRoom = try await transport.call(["op": "join", "kind": "native", "name": name], token: caps.owner)
            owner = caps.owner; edit = caps.edit; view = caps.view; seat = joined.participantCapability
            dirty = false; conflict = false; room = joined; connected = true
            status = "Room created for one hour. Share Edit/View deliberately; keep your own copy."; save()
        } catch { status = error.localizedDescription }
    }
    func join(_ url: URL, name: String, replacingSavedDraft: Bool = false) async {
        guard !isBusy, !isRunning else { return }
        guard !dirty || replacingSavedDraft else { status = "Save your draft as a separate project before joining another room."; return }
        guard let cap = PlaygroundLink.capability(url) else { status = "Use a valid gopherforge.app Playground link."; return }
        isBusy = true; defer { isBusy = false }
        do {
            let joined: PlaygroundRoom = try await transport.call(["op": "join", "kind": "native", "name": name], token: cap)
            room = joined; files = joined.files; seat = joined.participantCapability
            owner = nil; edit = joined.role == "view" ? nil : cap; view = joined.role == "view" ? cap : nil
            dirty = false; conflict = false; connected = true; selectedFile = "main.go"
            status = "Joined. Nothing runs until you press Run/Test on this device."; save()
        } catch { status = error.localizedDescription }
    }
    @discardableResult func publish() async -> Bool {
        guard let room, let seat, !conflict, !isBusy else { return !dirty }
        if !dirty { return true }
        isBusy = true; defer { isBusy = false }
        let sent = files
        do {
            let next: PlaygroundRoom = try await transport.call(["op": "write", "revision": room.revision, "files": sent], token: seat)
            self.room = next; if exact(files, sent) { dirty = false }
            connected = true; status = "Source shared. Nothing executed."; save(); return !dirty
        } catch { conflict = true; status = error.localizedDescription; return false }
    }
    func poll() async {
        guard let seat, !isBusy else { return }
        do {
            if let pending {
                let _: PlaygroundRoom = try await transport.call(["op": "finish_run", "runID": pending.runID, "stdout": pending.stdout, "stderr": pending.stderr, "succeeded": pending.succeeded], token: seat)
                self.pending = nil
            }
            let next: PlaygroundRoom = try await transport.call(["op": "read"], token: seat)
            guard self.seat == seat, !isBusy, next.id == room?.id, next.revision >= (room?.revision ?? 0) else { return }
            if dirty && next.revision != room?.revision { conflict = true }
            if !dirty { files = next.files }
            room = next; connected = true; save()
        } catch { connected = false; status = "\(error.localizedDescription) Local source and unpublished results are kept." }
    }
    func loadLatest() {
        guard let room, !isRunning, !isBusy else { return }
        files = room.files; dirty = false; conflict = false; selectedFile = "main.go"; save()
    }
    /// The ONLY compiler entry. Called exclusively by local buttons, never by poll/join/MCP.
    func run(test: Bool, requestID: String? = nil) async {
        guard !isRunning, !isBusy, canEdit else { return }
        if room != nil, !(await publish()) { return }
        isRunning = true; defer { isRunning = false }
        var runID: String?
        let source: [String: String]
        if let room, let seat {
            struct Begun: Decodable { let run: PlaygroundRoom.Run; let files: [String: String] }
            var payload: [String: Any] = ["op": "begin_run", "revision": room.revision, "phase": test ? "test" : "run"]
            if let requestID { payload["requestID"] = requestID }
            do {
                let begun: Begun = try await transport.call(payload, token: seat)
                runID = begun.run.id; source = begun.files
            } catch { status = error.localizedDescription; return }
        } else { source = files }
        status = "Building locally on this device. Other participants receive Output only."
        let snapshot = GoSourceSnapshot(files: source, packagePattern: test ? "./..." : ".", entryFile: "main.go")
        let result: CompilationResult
        if let execute { result = await execute(snapshot, test) }
        else { result = test ? await compiler.test(project: snapshot) : await compiler.run(project: snapshot) }
        let stdout = bounded(result.stdout), stderr = bounded(result.stderr + (result.succeeded ? "" : "\n" + result.detail))
        localOutput = stdout + "\n" + stderr
        if let runID { pending = PendingResult(runID: runID, stdout: stdout, stderr: stderr, succeeded: result.succeeded); save(); await poll() }
        if !result.succeeded { status = "Local run failed. Read the diagnostic below." }
        else if runID == nil { status = "Local run finished. This draft was not uploaded." }
        else if pending != nil { status = "Local run finished. Output is kept here and waiting for reconnection." }
        else { status = "Local run finished. Shared Output identifies this device and the captured source revision." }
    }
    func close() async {
        guard let owner, !isRunning, !isBusy else { return }
        do {
            struct Closed: Decodable { let closed: Bool }
            let _: Closed = try await transport.call(["op": "close"], token: owner)
            room = nil; seat = nil; self.owner = nil; edit = nil; view = nil; connected = false; save()
            status = "Room closed. Your local copy is kept."
        } catch { status = error.localizedDescription }
    }
    func independentProject() -> GopherForgeProject {
        GopherForgeProject(name: "Playground copy", files: files, entryFile: "main.go", provenance: .files())
    }
    private func bounded(_ value: String) -> String {
        // Keep valid UTF-8 and stay within the relay's per-stream byte budget.
        var bytes = Array(value.utf8.prefix(64 * 1024))
        while String(bytes: bytes, encoding: .utf8) == nil && !bytes.isEmpty { bytes.removeLast() }
        return String(decoding: bytes, as: UTF8.self)
    }
    private func exact(_ lhs: [String: String], _ rhs: [String: String]) -> Bool {
        lhs.keys.count == rhs.keys.count && lhs.allSatisfy { key, value in rhs[key].map { value.utf8.elementsEqual($0.utf8) } ?? false }
    }
}
