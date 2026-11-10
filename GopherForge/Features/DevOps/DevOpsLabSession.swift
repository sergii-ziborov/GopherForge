import CryptoKit
import Foundation
import Observation
import WasmKit

struct DevOpsLabState: Codable, Sendable {
    var files: [String: String]
    var dirs: [String: Bool]
    var vars: [String: String]
    var cwd: String

    static func initial(_ lab: DevOpsLab) -> Self {
        var dirs = ["/lab": true]
        let files = Dictionary(uniqueKeysWithValues: lab.initialFiles.map { ("/lab/" + $0.key, $0.value) })
        for name in files.keys {
            var parent = (name as NSString).deletingLastPathComponent
            while parent.hasPrefix("/lab/") { dirs[parent] = true; parent = (parent as NSString).deletingLastPathComponent }
        }
        return Self(files: files, dirs: dirs, vars: [:], cwd: "/lab")
    }
    func validate() throws {
        func safe(_ path: String) -> Bool {
            path.utf8.count <= 256 && !path.contains("\0") && (path == "/lab" || path.hasPrefix("/lab/"))
                && (path as NSString).standardizingPath == path
        }
        guard files.count <= 96, files.count + dirs.count <= 128, vars.count <= 64,
              dirs["/lab"] == true, dirs[cwd] == true,
              dirs.allSatisfy({ safe($0.key) && $0.value && files[$0.key] == nil }),
              files.allSatisfy({ safe($0.key) && $0.value.utf8.count <= 65_536 }),
              vars.allSatisfy({ $0.key.utf8.count <= 128 && $0.value.utf8.count <= 4096 }),
              files.values.reduce(0, { $0 + $1.utf8.count }) + vars.reduce(0, { $0 + $1.key.utf8.count + $1.value.utf8.count }) <= 2 * 1024 * 1024 else {
            throw CourseContentError.invalid("The lab state exceeds its storage limits.")
        }
    }
}

struct DevOpsShellResult: Codable, Sendable {
    let state: DevOpsLabState
    let stdout: String
    let stderr: String
    let status: Int
}

actor DevOpsShellRunner {
    static let shared = DevOpsShellRunner()
    private let engineProvider = WasmEngineProvider()
    func run(source: String, state: DevOpsLabState, cancellation: WasiCancellation) throws -> DevOpsShellResult {
        guard source.utf8.count <= 16_384 else { throw CourseContentError.invalid("A lab script can contain up to 16 KiB.") }
        try state.validate()
        guard let root = Bundle.main.url(forResource: "DevOpsShell", withExtension: nil),
              let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appending(path: "manifest.json"))) as? [String: String] else {
            throw CourseContentError.invalid("The bundled DevOps shell is unavailable.")
        }
        let bytes = try Data(contentsOf: root.appending(path: "shell.wasm"))
        guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == manifest["sha256"] else {
            throw CourseContentError.invalid("The bundled DevOps shell failed its integrity check.")
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "DevOpsRun-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        struct Request: Encodable { let source: String; let state: DevOpsLabState }
        try JSONEncoder().encode(Request(source: source, state: state)).write(to: folder.appending(path: "request.json"))
        let module = try parseWasm(bytes: Array(bytes))
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

@MainActor @Observable
final class DevOpsLabSession {
    let lab: DevOpsLab
    private(set) var state: DevOpsLabState
    var source: String { didSet { queueDraftSave() } }
    private(set) var transcript = "Type help to see the supported shell language and limits."
    private(set) var isRunning = false
    private(set) var needsReset = false
    private(set) var status: String?
    private var cancellation: WasiCancellation?
    private let storage: URL
    private var draftSaveTask: Task<Void, Never>?
    private var storageFingerprint: Data?
    private struct SavedLab: Codable { let state: DevOpsLabState; let source: String }

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
                    state = saved.state; source = saved.source
                } else {
                    let saved = try JSONDecoder().decode(DevOpsLabState.self, from: data)
                    try saved.validate(); state = saved
                }
            } catch { needsReset = true; status = "The saved lab could not be read. Reset this lab to continue; other work is unchanged." }
        }
    }
    func stop() { cancellation?.cancel() }
    func run() async {
        guard !isRunning, !needsReset else { return }
        isRunning = true; status = nil
        let token = WasiCancellation(); cancellation = token
        let script = source
        defer { isRunning = false; cancellation = nil }
        do {
            let result = try await DevOpsShellRunner.shared.run(source: script, state: state, cancellation: token)
            try persist(result.state); state = result.state
            transcript += "\n\n$ \(script)\n\(result.stdout)\(result.stderr)\nexit \(result.status)"
            if transcript.utf8.count > 131_072 { transcript = "Earlier transcript trimmed.\n" + String(decoding: Data(transcript.utf8).suffix(130_000), as: UTF8.self) }
        } catch { transcript = error.localizedDescription }
    }
    func reset() {
        guard !isRunning else { return }
        draftSaveTask?.cancel()
        do { let fresh = DevOpsLabState.initial(lab); try fresh.validate(); try persist(fresh); state = fresh; needsReset = false; status = nil; transcript = "This lab was reset." }
        catch { status = error.localizedDescription }
    }
    private func persist(_ value: DevOpsLabState) throws {
        guard source.utf8.count <= 65_536 else { throw CourseContentError.invalid("A saved script draft can contain up to 64 KiB; execution is limited to 16 KiB.") }
        let current = try? Data(contentsOf: storage)
        guard current.map({ Data(SHA256.hash(data: $0)) }) == storageFingerprint else {
            throw CourseContentError.invalid("Another window changed this lab. Your script is still visible; copy it before reopening the lab to reload the saved files.")
        }
        try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(SavedLab(state: value, source: source))
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
