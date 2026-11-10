import CryptoKit
import Foundation
import Observation
import WasmKit

struct DevOpsLabState: Codable, Sendable {
    var files: [String: String]
    var dirs: [String: Bool]
    var vars: [String: String]
    var cwd: String
    /// Shell functions, kept as source so one prompt can call what another defined.
    var funcs: [String: String]?

    static func initial(_ lab: DevOpsLab) -> Self {
        var dirs = ["/lab": true]
        let files = Dictionary(uniqueKeysWithValues: lab.initialFiles.map { ("/lab/" + $0.key, $0.value) })
        for name in files.keys {
            var parent = (name as NSString).deletingLastPathComponent
            while parent.hasPrefix("/lab/") { dirs[parent] = true; parent = (parent as NSString).deletingLastPathComponent }
        }
        return Self(files: files, dirs: dirs, vars: [:], cwd: "/lab")
    }
    static func isSafe(_ path: String) -> Bool {
        path.utf8.count <= 256 && !path.contains("\0") && (path == "/lab" || path.hasPrefix("/lab/"))
            && (path as NSString).standardizingPath == path
    }
    func validate() throws {
        let funcs = funcs ?? [:]
        guard files.count <= 96, files.count + dirs.count <= 128, vars.count <= 64, funcs.count <= 32,
              dirs["/lab"] == true, dirs[cwd] == true,
              dirs.allSatisfy({ Self.isSafe($0.key) && $0.value && files[$0.key] == nil }),
              files.allSatisfy({ Self.isSafe($0.key) && $0.value.utf8.count <= 65_536 }),
              vars.allSatisfy({ $0.key.utf8.count <= 128 && $0.value.utf8.count <= 4096 }),
              funcs.allSatisfy({ $0.key.utf8.count <= 64 && $0.value.utf8.count <= 8192 }),
              files.values.reduce(0, { $0 + $1.utf8.count }) + vars.reduce(0, { $0 + $1.key.utf8.count + $1.value.utf8.count })
                + funcs.reduce(0, { $0 + $1.key.utf8.count + $1.value.utf8.count }) <= 2 * 1024 * 1024 else {
            throw CourseContentError.invalid("The lab state exceeds its storage limits.")
        }
    }
}

struct DevOpsShellResult: Codable, Sendable {
    struct Chunk: Codable, Sendable {
        let text: String
        let error: Bool?
    }
    let state: DevOpsLabState
    let stdout: String
    let stderr: String
    let status: Int
    /// The input ended inside a quote, block or heredoc, and nothing ran.
    let incomplete: Bool?
    /// Stdout and stderr in the order the statements produced them.
    let output: [Chunk]?
}

actor DevOpsShellRunner {
    static let shared = DevOpsShellRunner()
    private let engineProvider = WasmEngineProvider()
    /// Verified and parsed once: the prompt runs the shell for every line, and
    /// hashing and parsing 7 MB each time would be most of the wait.
    private var module: Module?

    private func shellModule() throws -> Module {
        if let module { return module }
        guard let root = Bundle.main.url(forResource: "DevOpsShell", withExtension: nil),
              let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appending(path: "manifest.json"))) as? [String: String] else {
            throw CourseContentError.invalid("The bundled DevOps shell is unavailable.")
        }
        let bytes = try Data(contentsOf: root.appending(path: "shell.wasm"))
        guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == manifest["sha256"] else {
            throw CourseContentError.invalid("The bundled DevOps shell failed its integrity check.")
        }
        let parsed = try parseWasm(bytes: Array(bytes))
        module = parsed
        return parsed
    }

    func run(source: String, state: DevOpsLabState, cancellation: WasiCancellation) throws -> DevOpsShellResult {
        guard source.utf8.count <= 16_384 else { throw CourseContentError.invalid("A lab script can contain up to 16 KiB.") }
        try state.validate()
        let module = try shellModule()
        let folder = FileManager.default.temporaryDirectory.appending(path: "DevOpsRun-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        struct Request: Encodable { let source: String; let state: DevOpsLabState }
        try JSONEncoder().encode(Request(source: source, state: state)).write(to: folder.appending(path: "request.json"))
        let (code, output) = try WasiProcessRunner(engineProvider: engineProvider).run(module: module, invocation: .init(
            arguments: ["gopherforge-shell"], environment: ["GOMEMLIMIT": "48MiB"], preopens: ["/control": folder.path],
            memoryLimitBytes: 64 * 1024 * 1024, outputLimitBytes: 65_536, cancellation: cancellation))
        guard code == 0 else { throw CourseContentError.invalid("The lab runtime stopped (\(code)). \(output.stderr)") }
        let url = folder.appending(path: "response.json")
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 16 * 1024 * 1024 else { throw CourseContentError.invalid("Lab response exceeded its limit.") }
        let result = try JSONDecoder().decode(DevOpsShellResult.self, from: Data(contentsOf: url))
        try result.state.validate()
        guard result.stdout.utf8.count + result.stderr.utf8.count <= 131_072 else { throw CourseContentError.invalid("Lab output exceeded its limit.") }
        return result
    }
}

/// One exchange at the prompt: what was typed and what came back.
struct DevOpsTerminalEntry: Identifiable, Equatable {
    enum Kind: Equatable { case command, output, error, notice }
    let id = UUID()
    let kind: Kind
    let text: String
    /// The working directory shown in the prompt of a command.
    var cwd = ""
    /// A continuation line of a multi-line command, shown after a `>` prompt.
    var continuation = false
    /// The exit status, set on the command once it finishes.
    var status: Int?
    /// Output of ls or tree, whose directories and scripts are coloured.
    var listing = false
}

/// A file the terminal asked the editor to open, from `nano FILE` or the file list.
struct DevOpsEditorRequest: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let contents: String
    let isNew: Bool
    var name: String { (path as NSString).lastPathComponent }
}

@MainActor @Observable
final class DevOpsLabSession {
    let lab: DevOpsLab
    private(set) var state: DevOpsLabState
    /// The guided lab's script, which Run executes as a whole.
    var source: String { didSet { queueDraftSave() } }
    private(set) var entries: [DevOpsTerminalEntry] = []
    var input = ""
    private(set) var isRunning = false
    private(set) var needsReset = false
    private(set) var status: String?
    /// Lines typed so far of a command that is not finished yet.
    private(set) var continuation: String?
    private(set) var history: [String] = []
    var editor: DevOpsEditorRequest?
    /// Set by `exit` at the prompt; the screen closes.
    private(set) var exitRequested = false
    private var queued: [String] = []
    private var draining = false
    private var historyCursor: Int?
    private var historyDraft = ""
    private var lastStatus = 0
    private var cancellation: WasiCancellation?
    private let storage: URL
    private var draftSaveTask: Task<Void, Never>?
    private var storageFingerprint: Data?
    private struct SavedLab: Codable { let state: DevOpsLabState; let source: String; var history: [String]? }

    static let editors: Set<String> = ["nano", "vi", "vim", "edit", "code", "open", "pico", "emacs"]
    static let commands = [
        "awk", "base64", "basename", "bash", "break", "cat", "cd", "chmod", "clear", "command", "continue", "cp", "cut",
        "date", "df", "diff", "dirname", "du", "echo", "edit", "env", "eval", "exit", "export", "false", "find", "grep",
        "head", "help", "history", "hostname", "id", "local", "ls", "man", "mkdir", "mv", "nano", "nl", "printenv",
        "printf", "pwd", "read", "readonly", "realpath", "return", "rev", "rm", "rmdir", "sed", "seq", "set", "sh",
        "sha256sum", "shift", "sleep", "sort", "source", "tail", "tee", "test", "touch", "tr", "tree", "true", "type",
        "uname", "uniq", "unset", "vi", "vim", "wc", "which", "whoami", "xargs",
    ]

    init(lab: DevOpsLab, storage: URL? = nil) {
        self.lab = lab; source = lab.starter; state = .initial(lab)
        let safeID = lab.id.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        self.storage = storage ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "GopherForge/DevOpsLabs/\(safeID).json")
        if FileManager.default.fileExists(atPath: self.storage.path) {
            do {
                let size = try self.storage.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= 16 * 1024 * 1024 else { throw CourseContentError.invalid("Saved lab exceeds its limit.") }
                let data = try Data(contentsOf: self.storage)
                storageFingerprint = Data(SHA256.hash(data: data))
                if let saved = try? JSONDecoder().decode(SavedLab.self, from: data) {
                    try saved.state.validate()
                    guard saved.source.utf8.count <= 65_536 else { throw CourseContentError.invalid("Saved draft exceeds its limit.") }
                    state = saved.state; source = saved.source; history = Array((saved.history ?? []).suffix(200))
                } else {
                    let saved = try JSONDecoder().decode(DevOpsLabState.self, from: data)
                    try saved.validate(); state = saved
                }
            } catch { needsReset = true; status = "The saved lab could not be read. Reset this lab to continue; other work is unchanged." }
        }
        welcome()
    }

    /// Everything the terminal shows, as plain text.
    var transcript: String {
        entries.map { entry in
            entry.kind == .command ? (entry.continuation ? "> " : "$ ") + entry.text : entry.text
        }.joined(separator: "\n")
    }

    /// `~` for /lab, as a shell prompt abbreviates the home directory.
    var promptDirectory: String { Self.abbreviate(state.cwd) }
    static func abbreviate(_ path: String) -> String {
        path == "/lab" ? "~" : path.hasPrefix("/lab/") ? "~" + path.dropFirst(4) : path
    }
    var lastCommandFailed: Bool { lastStatus != 0 }

    private func welcome() {
        let files = state.files.count
        append(.notice, "GopherForge lab shell · offline · \(files) file\(files == 1 ? "" : "s")\n"
            + (files == 0 ? "help lists commands; try mkdir notes" : "help lists commands, ls -la shows files"))
    }

    func stop() { cancellation?.cancel() }

    /// Runs what was typed at the prompt. Lines entered while a command is
    /// still running wait their turn, as type-ahead does in a terminal.
    func submit() async {
        let line = input
        input = ""
        queued.append(line)
        await drain()
    }

    /// Queues a line taken from the prompt the moment Return was pressed, so
    /// fast typing or a pasted script cannot run into the next line.
    func enter(_ line: String) {
        queued.append(line)
        Task { await drain() }
    }

    private func drain() async {
        historyCursor = nil
        guard !draining else { return }
        draining = true
        defer { draining = false }
        while !queued.isEmpty, !needsReset {
            await process(queued.removeFirst())
        }
        queued.removeAll()
    }

    private func process(_ line: String) async {
        append(.command, line, continuation: continuation != nil)
        var command = continuation.map { $0 + "\n" + line } ?? line
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, continuation == nil { return }
        if continuation == nil, handleLocally(trimmed) {
            remember(trimmed)
            return
        }
        if command.contains("!!"), let previous = history.last {
            command = command.replacingOccurrences(of: "!!", with: previous)
            append(.notice, command)
        }
        let result = await execute(command, interactive: true)
        if result?.incomplete == true {
            continuation = command
            return
        }
        continuation = nil
        remember(command)
        let head = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        if let result { show(result, listing: ["ls", "tree"].contains(head) && !trimmed.contains("|")) }
    }

    /// Runs the guided lab's script as one command.
    func run() async {
        guard !isRunning, !draining, !needsReset else { return }
        continuation = nil
        let lines = source.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() where !(index == lines.count - 1 && line.isEmpty) {
            append(.command, line, continuation: index > 0)
        }
        if let result = await execute(source, interactive: false) { show(result) }
    }

    /// Ctrl-C: stops a running command and anything typed ahead of it, or
    /// abandons the line being typed.
    func interrupt() {
        queued.removeAll()
        if isRunning { stop(); return }
        append(.command, input + "^C", continuation: continuation != nil)
        input = ""
        continuation = nil
        historyCursor = nil
    }

    func clear() { entries.removeAll() }

    /// At the prompt, input that stops inside a quote or block asks for the
    /// next line; a script that does the same is a syntax error.
    private func execute(_ script: String, interactive: Bool) async -> DevOpsShellResult? {
        isRunning = true; status = nil
        let token = WasiCancellation(); cancellation = token
        defer { isRunning = false; cancellation = nil }
        do {
            let result = try await DevOpsShellRunner.shared.run(source: script, state: state, cancellation: token)
            if result.incomplete == true, interactive { return result }
            try persist(result.state); state = result.state
            return result
        } catch {
            append(.error, error.localizedDescription)
            markLastCommand(status: 2)
            return nil
        }
    }

    private func show(_ result: DevOpsShellResult, listing: Bool = false) {
        let chunks = result.output ?? [.init(text: result.stdout, error: false), .init(text: result.stderr, error: true)]
        for chunk in chunks where !chunk.text.isEmpty {
            var text = chunk.text
            // `clear` inside a script prints the terminal's erase sequence.
            if let range = text.range(of: "\u{1b}[2J", options: .backwards) {
                entries.removeAll()
                text = String(text[range.upperBound...])
                if text.isEmpty { continue }
            }
            if text.hasSuffix("\n") { text.removeLast() }
            append(chunk.error == true ? .error : .output, text)
            if listing, chunk.error != true { entries[entries.count - 1].listing = true }
        }
        lastStatus = result.status
        markLastCommand(status: result.status)
    }

    private func markLastCommand(status: Int) {
        lastStatus = status
        guard let index = entries.lastIndex(where: { $0.kind == .command && !$0.continuation }) else { return }
        entries[index].status = status
    }

    /// Commands that belong to the terminal rather than the shell.
    private func handleLocally(_ line: String) -> Bool {
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let head = words.first, !line.contains(where: { ";|&<>$`\"'(".contains($0) }) else { return false }
        switch head {
        case "clear", "reset":
            guard words.count == 1 else { return false }
            clear()
        case "history":
            if words.dropFirst().first == "-c" {
                history.removeAll(); saveDraft()
            } else if !history.isEmpty {
                let start = max(0, history.count - 50)
                append(.output, history[start...].enumerated()
                    .map { String(format: "%5d", start + $0.offset + 1) + "  " + $0.element }.joined(separator: "\n"))
            }
        case "exit", "logout":
            guard words.count == 1 else { return false }
            exitRequested = true
        case _ where Self.editors.contains(head):
            guard words.count == 2 else {
                append(.error, "\(head): name one file, for example \(head) notes.txt")
                markLastCommand(status: 1)
                return true
            }
            openEditor(words[1])
        default:
            return false
        }
        markLastCommand(status: 0)
        return true
    }

    /// Resolves a path the way the shell does, refusing anything outside /lab.
    func resolve(_ path: String) -> String? {
        var path = path
        if path == "~" || path.hasPrefix("~/") { path = "/lab" + path.dropFirst() }
        if !path.hasPrefix("/") { path = state.cwd + "/" + path }
        let standard = (path as NSString).standardizingPath
        return DevOpsLabState.isSafe(standard) ? standard : nil
    }

    func openEditor(_ name: String) {
        if let request = editorRequest(for: name) { editor = request }
    }

    /// What the editor should open for a path, or nil after explaining why not.
    func editorRequest(for name: String) -> DevOpsEditorRequest? {
        let problem: String
        if let path = resolve(name) {
            if state.dirs[path] == true {
                problem = "\(name): Is a directory"
            } else if state.dirs[(path as NSString).deletingLastPathComponent] != true {
                problem = "\(name): No such directory. Create it first with mkdir -p"
            } else {
                return DevOpsEditorRequest(path: path, contents: state.files[path] ?? "", isNew: state.files[path] == nil)
            }
        } else {
            problem = "\(name): Permission denied (only /lab is available)"
        }
        append(.error, problem)
        markLastCommand(status: 1)
        return nil
    }

    /// Writes the editor's text into the lab, as a shell redirect would.
    func save(_ contents: String, to path: String) throws {
        guard !isRunning else { throw CourseContentError.invalid("Wait for the running command to finish.") }
        guard contents.utf8.count <= 65_536 else { throw CourseContentError.invalid("A lab file can contain up to 64 KiB.") }
        var next = state
        guard next.dirs[(path as NSString).deletingLastPathComponent] == true, next.dirs[path] == nil else {
            throw CourseContentError.invalid("The folder for this file no longer exists.")
        }
        next.files[path] = contents
        try next.validate()
        try persist(next); state = next
        append(.notice, "Saved \(Self.abbreviate(path)) · \(contents.utf8.count) bytes")
    }

    /// Puts text at the prompt, as though it had been typed.
    func type(_ text: String) {
        input += input.isEmpty || input.hasSuffix(" ") ? text : " " + text
    }

    /// Runs a command chosen in the interface, so it shows in the transcript.
    func perform(_ command: String) async {
        guard !isRunning, !draining, continuation == nil else { return }
        let typed = input
        input = command
        await submit()
        input = typed
    }

    // MARK: History

    private func remember(_ command: String) {
        let line = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, history.last != line else { return }
        history.append(line)
        if history.count > 200 { history.removeFirst(history.count - 200) }
        saveDraft()
    }

    func historyUp() {
        guard !history.isEmpty else { return }
        if historyCursor == nil { historyDraft = input; historyCursor = history.count }
        historyCursor = max(0, historyCursor! - 1)
        input = history[historyCursor!]
    }

    func historyDown() {
        guard let cursor = historyCursor else { return }
        if cursor + 1 >= history.count {
            historyCursor = nil
            input = historyDraft
        } else {
            historyCursor = cursor + 1
            input = history[cursor + 1]
        }
    }

    // MARK: Completion

    /// Tab: completes a command or a lab path, or lists the choices.
    func complete() {
        let words = input.split(separator: " ", omittingEmptySubsequences: false)
        let current = String(words.last ?? "")
        let isCommand = words.count == 1 && !current.contains("/")
        var candidates: [String]
        var base = ""
        if isCommand {
            let names = Self.commands + Array((state.funcs ?? [:]).keys)
            candidates = Set(names).filter { $0.hasPrefix(current) }.sorted()
        } else {
            let slash = current.lastIndex(of: "/")
            base = slash.map { String(current[...$0]) } ?? ""
            let prefix = slash.map { String(current[current.index(after: $0)...]) } ?? current
            guard let dir = base.isEmpty ? state.cwd : resolve(base), state.dirs[dir] == true else { return }
            let children = state.files.keys.filter { ($0 as NSString).deletingLastPathComponent == dir }
                .map { ($0 as NSString).lastPathComponent }
                + state.dirs.keys.filter { $0 != dir && ($0 as NSString).deletingLastPathComponent == dir }
                .map { ($0 as NSString).lastPathComponent + "/" }
            candidates = children.filter { $0.hasPrefix(prefix) && (prefix.hasPrefix(".") || !$0.hasPrefix(".")) }.sorted()
        }
        guard !candidates.isEmpty else { return }
        let head = words.dropLast().joined(separator: " ")
        let lead = head.isEmpty ? "" : head + " "
        if candidates.count == 1 {
            let done = candidates[0]
            input = lead + base + done + (done.hasSuffix("/") ? "" : " ")
            return
        }
        let common = candidates.dropFirst().reduce(candidates[0]) { $0.commonPrefix(with: $1) }
        let typed = isCommand ? current : String(current.dropFirst(base.count))
        if common.count > typed.count {
            input = lead + base + common
        } else {
            append(.command, input)
            append(.output, candidates.joined(separator: "  "))
        }
    }

    // MARK: Lab lifecycle

    func reset() {
        guard !isRunning else { return }
        draftSaveTask?.cancel()
        do {
            let fresh = DevOpsLabState.initial(lab); try fresh.validate(); try persist(fresh)
            state = fresh; needsReset = false; status = nil; continuation = nil
            entries.removeAll()
            welcome()
            append(.notice, lab.checks.isEmpty ? "The playground was reset to its starting files." : "This lab was reset to its starting files.")
        }
        catch { status = error.localizedDescription }
    }

    private func append(_ kind: DevOpsTerminalEntry.Kind, _ text: String, continuation: Bool = false) {
        var entry = DevOpsTerminalEntry(kind: kind, text: text, continuation: continuation)
        if kind == .command { entry.cwd = promptDirectory }
        entries.append(entry)
        if entries.count > 400 { entries.removeFirst(entries.count - 400) }
        let size = entries.reduce(0) { $0 + $1.text.utf8.count }
        if size > 262_144, let first = entries.indices.first(where: { entries[$0].kind == .command && $0 > 0 }) {
            entries.removeFirst(first)
        }
    }

    private func persist(_ value: DevOpsLabState) throws {
        guard source.utf8.count <= 65_536 else { throw CourseContentError.invalid("A saved script draft can contain up to 64 KiB; execution is limited to 16 KiB.") }
        let current = try? Data(contentsOf: storage)
        guard current.map({ Data(SHA256.hash(data: $0)) }) == storageFingerprint else {
            throw CourseContentError.invalid("Another window changed this lab. Your script is still visible; copy it before reopening the lab to reload the saved files.")
        }
        try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(SavedLab(state: value, source: source, history: history))
        try data.write(to: storage, options: .atomic)
        storageFingerprint = Data(SHA256.hash(data: data))
    }
    private func queueDraftSave() {
        draftSaveTask?.cancel()
        draftSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.saveDraft()
        }
    }
    func saveDraft() {
        draftSaveTask?.cancel()
        guard !needsReset else { return }
        do { try persist(state) } catch { status = error.localizedDescription }
    }
    var checks: [(description: String, passed: Bool)] {
        func exact(_ left: String?, _ right: String?) -> Bool {
            guard let left, let right else { return false }; return left.utf8.elementsEqual(right.utf8)
        }
        return lab.checks.map { check in
            let data = state.files["/lab/" + check.path]
            let passed: Bool
            if let expected = check.equals { passed = exact(data, expected) }
            else if let other = check.sameAs { passed = exact(data, lab.initialFiles[other]) }
            else if let source = check.sha256Of, let value = state.files["/lab/" + source] {
                passed = data?.trimmingCharacters(in: .whitespacesAndNewlines) == SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
            } else { passed = false }
            return (check.description, passed)
        }
    }
}
