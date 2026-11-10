import Foundation

struct PlaygroundRoom: Codable, Sendable {
    struct Cursor: Codable, Sendable { let path: String; let anchor: Int; let head: Int; let revision: Int }
    struct Change: Codable, Identifiable, Sendable { let id: String; let name: String; let revision: Int; let paths: [String] }
    struct Participant: Codable, Identifiable, Sendable { let id: String; let name: String; let kind: String; let cursor: Cursor? }
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
    let changes: [Change]?
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
            throw ServiceFailure(error: value?.error ?? "Connection failed. Your local source is kept.", statusCode: (response as? HTTPURLResponse)?.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    struct ServiceFailure: Codable, LocalizedError {
        let error: String; let statusCode: Int?
        init(error: String, statusCode: Int? = nil) { self.error = error; self.statusCode = statusCode }
        var errorDescription: String? { error }
    }
}

@MainActor @Observable
final class PlaygroundSession {
    // Every scene/deep link on this device uses one draft and one compiler owner.
    // Returning during an in-flight run cannot create a second writer to its file.
    static let shared = PlaygroundSession()
    let debugger = GoDebuggerModel()
    var revealLine: Int?
    private var debugOriginal: [String: String] = [:]
    private var preparedDependencies: [String: String] = [:]
    private var preparedManifest = ""
    private struct PackageCache: Codable { let manifest: String; let files: [String: String]; let modules: [String]; let hash: String }
    private(set) var preparedModules: [String] = []
    struct PendingResult: Codable {
        let runID: String; let stdout: String; let stderr: String; let succeeded: Bool
    }
    private struct Saved: Codable {
        let files: [String: String]; let seat: String?; let owner: String?; let edit: String?; let view: String?
        let room: PlaygroundRoom?; let dirty: Bool; let pending: PendingResult?
        let lastLocalOutput: String?
        let encrypted: EncryptedPlaygroundSession.Saved?
    }
    static let starter = ["go.mod": "module playground\n\ngo 1.27.1\n", "main.go": "package main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"Hello from my device\")\n}\n"]
    var files = starter
    var selectedFile = "main.go" { didSet { selectedFileIdentity = encrypted?.state.identities[selectedFile]; localCursor = nil } }
    private var selectedFileIdentity: String?
    private(set) var encrypted: EncryptedPlaygroundSession?
    private(set) var nickname = UserDefaults.standard.string(forKey: "playground.nickname.v1") ?? ""
    private var localCursor: PlaygroundRoom.Cursor?
    var hasRoom: Bool { room != nil || encrypted != nil }
    var remoteCursors: [PlaygroundPeerCursor] {
        if let encrypted { return encrypted.state.cursors }
        return room?.participants.compactMap { peer in
            guard peer.id != room?.participantID, let cursor = peer.cursor, cursor.revision == room?.revision else { return nil }
            return PlaygroundPeerCursor(id: peer.id, name: peer.name, color: PlaygroundIdentity.color(peer.id), path: cursor.path, anchor: cursor.anchor, head: cursor.head)
        } ?? []
    }
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
    var canEdit: Bool { room?.role != "view" && encrypted?.role != "view" }
    var canClose: Bool { owner != nil || encrypted?.canClose == true }
    var shareURL: URL? { encrypted?.shareURL ?? (edit ?? view).map(PlaygroundLink.web) }
    var viewURL: URL? { encrypted?.viewURL ?? view.map(PlaygroundLink.web) }
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
            localOutput = saved.lastLocalOutput ?? ""
            if let secure = saved.encrypted {
                encrypted = try? EncryptedPlaygroundSession(transport: transport, name: secure.name, saved: secure)
                if let encrypted { files = encrypted.state.files; nickname = encrypted.name }
            }
            status = "Local draft restored. Reconnecting never starts a run."
        }
        let packageURL = self.storageURL.appendingPathExtension("packages.json")
        if let size = try? packageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 16 * 1024 * 1024,
           let data = try? Data(contentsOf: packageURL), let cache = try? JSONDecoder().decode(PackageCache.self, from: data),
           cache.files.count <= 512, cache.files.keys.allSatisfy({ $0.hasPrefix("vendor/") && !$0.split(separator: "/").contains("..") }),
           cache.files.values.reduce(0, { $0 + $1.utf8.count }) <= 8 * 1024 * 1024,
           (try? PlaygroundCRDT.sourceHash(cache.files)) == cache.hash {
            preparedManifest = cache.manifest; preparedDependencies = cache.files; preparedModules = cache.modules
        }
    }
    func update(_ text: String) {
        guard canEdit else { return }
        if text.utf8.count > 128 * 1024 { status = "The collaborative editor limit is 128 KiB per file. Keep an exported copy."; return }
        if let encrypted {
            do { try encrypted.change(["op": "edit", "path": selectedFile, "text": text]); refreshEncrypted(); save() }
            catch { status = error.localizedDescription }
            return
        }
        files[selectedFile] = text; dirty = true; save()
    }
    func addFile(_ name: String) {
        guard canEdit, !isRunning, !isBusy, Self.safePath(name), name.hasSuffix(".go"), files[name] == nil, files.count < 32,
              !files.keys.contains(where: { $0.hasPrefix(name + "/") || name.hasPrefix($0 + "/") }) else { status = "Use a new relative .go path (up to 32 files)."; return }
        let folder = name.split(separator: "/").dropLast().last.map(String.init) ?? "main"
        let packageName = folder.range(of: "^[a-zA-Z_][a-zA-Z0-9_]*$", options: .regularExpression) != nil ? folder : "main"
        let stub = "package \(packageName)\n"
        if let encrypted {
            do { var next = files; next[name] = stub; try encrypted.change(["op": "replace", "files": next]); selectedFile = name; refreshEncrypted(); save() }
            catch { status = error.localizedDescription }; return
        }
        files[name] = stub; selectedFile = name; dirty = true; save()
    }
    private func save() {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let value = Saved(files: files, seat: seat, owner: owner, edit: edit, view: view, room: room, dirty: dirty, pending: pending, lastLocalOutput: localOutput, encrypted: try encrypted?.saved())
            try JSONEncoder().encode(value).write(to: storageURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { status = "Draft could not be saved: \(error.localizedDescription). Save a separate project copy before leaving." }
    }
    func create(name: String, encrypted encryptedMode: Bool = false) async {
        guard !isBusy, !isRunning else { return }; isBusy = true; defer { isBusy = false }
        do {
            let name = try PlaygroundIdentity.nickname(name); nickname = name; UserDefaults.standard.set(name, forKey: "playground.nickname.v1")
            if encryptedMode {
                let shared = try EncryptedPlaygroundSession(transport: transport, name: name, files: files)
                try await shared.create(); encrypted = shared; room = nil; seat = nil; owner = nil; edit = nil; view = nil
                refreshEncrypted(); save(); return
            }
            let created: PlaygroundRoom = try await transport.call(["op": "create", "files": files, "title": "Go study room", "ttlSeconds": 3600])
            guard let caps = created.capabilities else { return }
            let joined: PlaygroundRoom = try await transport.call(["op": "join", "kind": "native", "name": name], token: caps.owner)
            owner = caps.owner; edit = caps.edit; view = caps.view; seat = joined.participantCapability
            pending = nil; localOutput = ""
            dirty = false; conflict = false; room = joined; connected = true
            status = "Room created for one hour. Share Edit/View deliberately; keep your own copy."; save()
        } catch { status = error.localizedDescription }
    }
    func join(_ url: URL, name: String, replacingSavedDraft: Bool = false) async {
        guard !isBusy, !isRunning else { return }
        guard !dirty || replacingSavedDraft else { status = "Save your draft as a separate project before joining another room."; return }
        if let secureLink = try? EncryptedPlaygroundLink(url) {
            isBusy = true; defer { isBusy = false }
            do {
                let name = try PlaygroundIdentity.nickname(name)
                let shared = try EncryptedPlaygroundSession(transport: transport, name: name)
                try await shared.join(secureLink.url); encrypted = shared; room = nil; seat = nil; owner = nil; edit = nil; view = nil
                nickname = name; UserDefaults.standard.set(name, forKey: "playground.nickname.v1"); refreshEncrypted(); save()
            } catch { status = error.localizedDescription }; return
        }
        guard let cap = PlaygroundLink.capability(url) else { status = "Use a valid gopherforge.app Playground link."; return }
        isBusy = true; defer { isBusy = false }
        do {
            let name = try PlaygroundIdentity.nickname(name); nickname = name; UserDefaults.standard.set(name, forKey: "playground.nickname.v1")
            let joined: PlaygroundRoom = try await transport.call(["op": "join", "kind": "native", "name": name], token: cap)
            room = joined; files = joined.files; seat = joined.participantCapability
            pending = nil; localOutput = ""
            owner = nil; edit = joined.role == "view" ? nil : cap; view = joined.role == "view" ? cap : nil
            dirty = false; conflict = false; connected = true; selectedFile = "main.go"
            status = "Joined. Nothing runs until you press Run/Test on this device."; save()
        } catch { status = error.localizedDescription }
    }
    @discardableResult func publish() async -> Bool {
        if let encrypted { await encrypted.sync(); refreshEncrypted(); save(); return encrypted.connected }
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
        if let encrypted, !isBusy { await encrypted.sync(); refreshEncrypted(); save(); return }
        guard let seat, !isBusy else { return }
        do {
            if let pending {
                let _: PlaygroundRoom = try await transport.call(["op": "finish_run", "runID": pending.runID, "stdout": pending.stdout, "stderr": pending.stderr, "succeeded": pending.succeeded], token: seat)
                guard self.seat == seat else { return }
                if self.pending?.runID == pending.runID { self.pending = nil }
            }
            var input: [String: Any] = ["op": "presence", "name": nickname.isEmpty ? "Native guest" : nickname]
            if let localCursor, localCursor.revision == room?.revision { input["cursor"] = ["path": localCursor.path, "anchor": localCursor.anchor, "head": localCursor.head, "revision": localCursor.revision] }
            let next: PlaygroundRoom = try await transport.call(input, token: seat)
            guard self.seat == seat, !isBusy, next.id == room?.id, next.revision >= (room?.revision ?? 0) else { return }
            if dirty && next.revision != room?.revision { conflict = true }
            if !dirty {
                if debugger.isActive && !exact(next.files, debugOriginal) { debugger.stop() }
                files = next.files
            }
            room = next; connected = true; save()
        } catch { connected = false; status = "\(error.localizedDescription) Local source and unpublished results are kept." }
    }
    func loadLatest() {
        guard let room, !isRunning, !isBusy else { return }
        files = room.files; dirty = false; conflict = false; selectedFile = "main.go"; save()
    }
    /// The ONLY compiler entry. Called exclusively by local buttons, never by poll/join/MCP.
    func run(test: Bool, requestID: String? = nil, debug: Bool = false) async {
        guard !isRunning, !isBusy else { return }
        if hasRoom && canEdit, !(await publish()) { return }
        isRunning = true; defer { isRunning = false }
        var runID: String?
        let source: [String: String]
        if let room, let seat, canEdit {
            struct Begun: Decodable { let run: PlaygroundRoom.Run; let files: [String: String] }
            var payload: [String: Any] = ["op": "begin_run", "revision": room.revision, "phase": test ? "test" : "run"]
            if let requestID { payload["requestID"] = requestID }
            do {
                let begun: Begun = try await transport.call(payload, token: seat)
                runID = begun.run.id; source = begun.files
            } catch { status = error.localizedDescription; return }
        } else { source = files }
        status = "Building locally on this device. Other participants receive Output only."
        let manifest = (source["go.mod"] ?? "") + "\0" + (source["go.sum"] ?? "")
        var buildFiles = source
        if manifest == preparedManifest { buildFiles.merge(preparedDependencies) { original, _ in original } }
        let snapshot = GoSourceSnapshot(files: buildFiles, packagePattern: test ? "./..." : ".", entryFile: "main.go")
        let useDebug = !test && (debug || debugger.hasBreakpoints)
        debugOriginal = source
        let result: CompilationResult
        if let execute { result = await execute(snapshot, test) }
        else if useDebug {
            result = await debugger.run(project: snapshot, compiler: compiler, pauseAtStart: debug, onProgress: { _ in }) { [weak self] pause in
                self?.selectedFile = pause.point.file; self?.revealLine = pause.point.line
            }
        }
        else { result = test ? await compiler.test(project: snapshot) : await compiler.run(project: snapshot) }
        let stdout = bounded(result.stdout), stderr = bounded(result.stderr + (result.succeeded ? "" : "\n" + result.detail))
        localOutput = stdout + "\n" + stderr
        save()
        if let encrypted {
            if encrypted.role == "view" { status = "Local run finished. View-only results are not published."; save(); return }
            do { try encrypted.publishResult(files: source, phase: test ? "test" : (useDebug ? "debug" : "run"), stdout: stdout, stderr: stderr, succeeded: result.succeeded); await encrypted.sync(); refreshEncrypted(); save() }
            catch { status = error.localizedDescription }
            return
        }
        if let runID { pending = PendingResult(runID: runID, stdout: stdout, stderr: stderr, succeeded: result.succeeded); save(); await poll() }
        if !result.succeeded { status = "Local run failed. Read the diagnostic below." }
        else if runID == nil { status = "Local run finished. This draft was not uploaded." }
        else if pending != nil { status = "Local run finished. Output is kept here and waiting for reconnection." }
        else { status = "Local run finished. Shared Output identifies this device and the captured source revision." }
    }
    func close() async {
        if let encrypted, !isRunning, !isBusy {
            do { try await encrypted.close(); self.encrypted = nil; connected = false; dirty = false; save(); status = "Room closed. Your local source is kept." }
            catch { status = error.localizedDescription }; return
        }
        guard let owner, !isRunning, !isBusy else { return }
        do {
            struct Closed: Decodable { let closed: Bool }
            let _: Closed = try await transport.call(["op": "close"], token: owner)
            room = nil; seat = nil; self.owner = nil; edit = nil; view = nil; connected = false; save()
            status = "Room closed. Your local copy is kept."
        } catch { status = error.localizedDescription }
    }
    /// Leaving is local and works even after expiry or a relay restart.
    func leave() {
        guard !isRunning, !isBusy else { return }
        encrypted = nil; room = nil; seat = nil; owner = nil; edit = nil; view = nil; pending = nil
        connected = false; conflict = false; dirty = false
        status = "Room left. Source and last local Output are kept here. You can run locally or create another room."
        save()
    }
    private func refreshEncrypted() {
        guard let encrypted else { return }
        let oldID = selectedFileIdentity
        if debugger.isActive && !exact(encrypted.state.files, debugOriginal) { debugger.stop() }
        files = encrypted.state.files
        if files[selectedFile] == nil { selectedFile = oldID.flatMap { id in encrypted.state.identities.first { $0.value == id }?.key } ?? files.keys.sorted().first ?? "main.go" }
        selectedFileIdentity = encrypted.state.identities[selectedFile]
        dirty = encrypted.hasPendingChanges; conflict = false; connected = encrypted.connected; status = encrypted.status
    }
    func setCursor(anchor: Int, head: Int) {
        if let encrypted { encrypted.cursor(path: selectedFile, anchor: anchor, head: head) }
        else if let room { localCursor = PlaygroundRoom.Cursor(path: selectedFile, anchor: anchor, head: head, revision: room.revision) }
    }
    func renameParticipant(_ value: String) async {
        do {
            let value = try PlaygroundIdentity.nickname(value)
            if let encrypted { try encrypted.updateIdentity(value); refreshEncrypted() }
            else if let seat { let next: PlaygroundRoom = try await transport.call(["op": "presence", "name": value], token: seat); room = next }
            nickname = value; UserDefaults.standard.set(value, forKey: "playground.nickname.v1"); save()
        } catch { status = error.localizedDescription }
    }
    func restoreSharedFile(_ id: String) {
        guard let encrypted else { return }
        do { try encrypted.change(["op": "restore", "id": id]); refreshEncrypted(); save() } catch { status = error.localizedDescription }
    }
    func preparePackages() async {
        guard !isBusy, !isRunning, canEdit else { return }; isBusy = true; defer { isBusy = false }
        let original = files, compiler = compiler
        status = "Preparing declared public Go modules on this device…"
        do {
            let preparer = GoDependencyPreparer(maximumModules: 24, planError: { files, skipping in
                let snapshot = GoSourceSnapshot(files: files, packagePattern: "./...", entryFile: "main.go")
                let missing = await Task.detached { compiler.missingImportPaths(phase: .test, project: snapshot) }.value
                guard let module = GoModParser.parse(files["go.mod"] ?? "") else { return nil }
                for path in missing.sorted() {
                    if case let .success(match) = GoRequirementMatch.resolve(importPath: path, module: module), skipping.contains(match.path) { continue }
                    return .unresolvedImport(path, importedBy: "Playground")
                }
                return nil
            }, install: { path, version, needed, source in
                try await GoPackageInstaller().install(path: path, version: version, into: source, neededImport: needed).files
            })
            let result = try await preparer.prepare(files: original)
            guard result.problems.isEmpty else { throw PlaygroundCRDT.Failure(result.problems.map(\.outputLine).joined(separator: "\n")) }
            let dependencies = result.files.filter { $0.key.hasPrefix("vendor/") && original[$0.key] == nil }
            guard dependencies.count <= 512, dependencies.values.reduce(0, { $0 + $1.utf8.count }) <= 8 * 1024 * 1024 else { throw PlaygroundCRDT.Failure("Prepared dependency source exceeds 512 files / 8 MiB. Use an independent project for this module graph.") }
            if let encrypted { await encrypted.sync(); refreshEncrypted() }
            guard exact(files, original) else { throw PlaygroundCRDT.Failure("Source changed during preparation. Your newer edits are kept; prepare again.") }
            var next = original
            if let sum = result.files["go.sum"] { next["go.sum"] = sum }
            if let encrypted { try encrypted.change(["op": "replace", "files": next]); refreshEncrypted() }
            else { files = next; dirty = room != nil }
            preparedDependencies = dependencies; preparedModules = result.installed
            preparedManifest = (files["go.mod"] ?? "") + "\0" + (files["go.sum"] ?? "")
            let cache = PackageCache(manifest: preparedManifest, files: dependencies, modules: result.installed, hash: try PlaygroundCRDT.sourceHash(dependencies))
            try JSONEncoder().encode(cache).write(to: storageURL.appendingPathExtension("packages.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            status = "Prepared \(result.installed.count) modules. Dependency source stays on this device."; save()
        } catch { status = error.localizedDescription }
    }
    func checkOrFormat(format: Bool) async {
        guard !isRunning, !isBusy, !format || canEdit else { return }; isRunning = true; defer { isRunning = false }
        let captured = files, manifest = (files["go.mod"] ?? "") + "\0" + (files["go.sum"] ?? "")
        var buildFiles = captured
        if manifest == preparedManifest { buildFiles.merge(preparedDependencies) { original, _ in original } }
        let source = GoSourceSnapshot(files: buildFiles, packagePattern: ".", entryFile: "main.go")
        let result = format ? await compiler.format(project: source) : await compiler.build(project: source)
        localOutput = result.stdout + "\n" + result.stderr + "\n" + result.detail
        if format && result.succeeded {
            guard exact(files, captured) else { status = "Source changed; formatted output was not applied."; return }
            var next = captured
            for (path, text) in result.formattedFiles where captured[path] != nil { next[path] = text }
            do { if let encrypted { try encrypted.change(["op": "replace", "files": next]); refreshEncrypted() }
                else { files = next; dirty = room != nil }
            } catch { status = error.localizedDescription; return }
        }
        status = result.succeeded ? (format ? "Source formatted locally." : "Build check passed. Nothing executed.") : result.detail
        save()
    }
    func changeFile(_ path: String, target: String? = nil, duplicate: Bool = false, remove: Bool = false) {
        guard canEdit, !isRunning, !isBusy, let source = files[path] else { return }
        if path == "main.go" && !duplicate { status = "Keep main.go as the entry point."; return }
        var next = files
        if remove { next.removeValue(forKey: path) }
        else {
            guard let target, Self.safePath(target), next[target] == nil,
                  !next.keys.contains(where: { $0.hasPrefix(target + "/") || target.hasPrefix($0 + "/") }) else { status = "Choose a new safe relative file path."; return }
            next[target] = source
            if !duplicate { next.removeValue(forKey: path) }
        }
        do {
            if let encrypted {
                if remove { try encrypted.change(["op": "delete", "path": path]) }
                else if !duplicate, let target { try encrypted.change(["op": "rename", "path": path, "target": target]) }
                else { try encrypted.change(["op": "replace", "files": next]) }
                refreshEncrypted()
            } else { files = next; dirty = true }
            if let target { selectedFile = target } else { selectedFile = "main.go" }
            save()
        } catch { status = error.localizedDescription }
    }
    private static func safePath(_ path: String) -> Bool {
        path.range(of: "^[a-zA-Z0-9_./-]{1,180}$", options: .regularExpression) != nil && !path.hasPrefix("/") && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !["", ".", "..", "__proto__", "constructor", "prototype"].contains(String($0)) }
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
