import Foundation
import Observation

@MainActor
@Observable
final class GoDebuggerModel {
    enum State: Equatable { case idle, preparing, running, paused, finished }
    private(set) var state: State = .idle
    private(set) var breakpoints: [String: Set<Int>] = [:]
    private(set) var pause: GoDebugPause?
    private(set) var message = ""
    private(set) var selectedFrame = 0
    var caretLine = 1
    private var control: GoDebugControl?
    private var key: String?
    private var generation = UUID()
    private let defaults: UserDefaults
    private let instrumenter = OfflineFrontendBuilder()

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var hasBreakpoints: Bool { breakpoints.values.contains { !$0.isEmpty } }
    var isActive: Bool { state == .preparing || state == .running || state == .paused }
    var breakpointCount: Int { breakpoints.values.reduce(0) { $0 + $1.count } }

    func openProject(_ id: UUID) {
        stop()
        generation = UUID()
        state = .idle
        pause = nil
        message = ""
        caretLine = 1
        key = "GopherForge.Debug.breakpoints." + id.uuidString
        let stored = key.flatMap(defaults.data(forKey:)).flatMap { try? JSONDecoder().decode([String: Set<Int>].self, from: $0) }
        breakpoints = stored ?? [:]
    }

    func toggle(file: String, line: Int) {
        guard !isActive, file.hasSuffix(".go"), !file.hasPrefix("vendor/"), line > 0 else { return }
        var lines = breakpoints[file] ?? []
        if lines.contains(line) { lines.remove(line) } else { lines.insert(line) }
        breakpoints[file] = lines.isEmpty ? nil : lines
        save()
    }

    func removeAll() { guard !isActive else { return }; breakpoints = [:]; save() }
    private func save() { if let key, let data = try? JSONEncoder().encode(breakpoints) { defaults.set(data, forKey: key) } }

    func resume(step: GoDebugControl.Step? = nil) {
        guard state == .paused else { return }
        pause = nil
        state = .running
        control?.resume(step: step)
    }

    func stop() {
        control?.stop()
        control = nil
        generation = UUID()
        if isActive { state = .finished; message = "Debug session stopped" }
        pause = nil
    }

    func selectFrame(_ index: Int) { selectedFrame = index }

    func run(project: GoSourceSnapshot, compiler: WasmGoCompiler, onProgress: @escaping GoBuildProgressHandler, onPause: @escaping @MainActor (GoDebugPause) -> Void) async -> CompilationResult {
        let current = UUID()
        generation = current
        state = .preparing
        pause = nil
        message = "Preparing source debugger…"
        defer {
            if generation == current { state = .finished; pause = nil; control = nil }
        }
        let checked = await compiler.build(project: project, onProgress: onProgress)
        guard generation == current else { return .failure(phase: .run, detail: "Debug session stopped.") }
        guard checked.succeeded else { return checked }
        do {
            let prepared = try await instrumenter.instrumentGo(files: project.files)
            guard generation == current else { return .failure(phase: .run, detail: "Debug session stopped.") }
            var bound: Set<Int> = []
            var unresolved: [String] = []
            for (file, lines) in breakpoints {
                let candidates = prepared.points.filter { $0.kind == 0 && $0.file == file }.sorted { $0.line < $1.line }
                for line in lines {
                    guard let next = candidates.first(where: { $0.line >= line }) else { unresolved.append("\(file):\(line)"); continue }
                    bound.formUnion(candidates.filter { $0.line == next.line }.map(\.id))
                }
            }
            guard unresolved.isEmpty, !bound.isEmpty else { throw OfflineFrontendError.message("No executable statement for \(unresolved.joined(separator: ", ")). Move the breakpoint to executable Go code.") }
            let debug = GoDebugControl(points: prepared.points, breakpoints: bound) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self, self.generation == current else { return }
                    self.pause = snapshot
                    self.selectedFrame = 0
                    self.state = .paused
                    self.message = "Paused · goroutine \(snapshot.goroutine)"
                    onPause(snapshot)
                }
            }
            control = debug
            state = .running
            message = "Source debugger running"
            var files = project.files
            files.merge(prepared.files) { _, instrumented in instrumented }
            let result = await compiler.run(project: GoSourceSnapshot(files: files, packagePattern: project.packagePattern, entryFile: project.entryFile, debugControl: debug), onProgress: onProgress)
            if generation == current { message = result.succeeded ? "Debug run finished" : result.detail }
            return result
        } catch { return .failure(phase: .run, detail: error.localizedDescription) }
    }
}
